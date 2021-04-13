#---------------------------------
# Local declarations
#---------------------------------
locals {
  resource_group_name = element(coalescelist(data.azurerm_resource_group.rgrp.*.name, azurerm_resource_group.rg.*.name, [""]), 0)
  location            = element(coalescelist(data.azurerm_resource_group.rgrp.*.location, azurerm_resource_group.rg.*.location, [""]), 0)
  if_ddos_enabled     = var.create_ddos_plan ? [{}] : []
  public_ip_map       = { for pip in var.public_ip_names : pip => true }

  fw_nat_rules = { for idx, rule in var.firewall_nat_rules : rule.name => {
    idx : idx,
    rule : rule,
    }
  }

  fw_network_rules = { for idx, rule in var.firewall_network_rules : rule.name => {
    idx : idx,
    rule : rule,
    }
  }

  fw_application_rules = { for idx, rule in var.firewall_application_rules : rule.name => {
    idx : idx,
    rule : rule,
    }
  }
}

#---------------------------------------------------------
# Resource Group Creation or selection - Default is "true"
#----------------------------------------------------------
data "azurerm_resource_group" "rgrp" {
  count = var.create_resource_group == false ? 1 : 0
  name  = var.resource_group_name
}

resource "azurerm_resource_group" "rg" {
  count    = var.create_resource_group ? 1 : 0
  name     = lower(var.resource_group_name)
  location = var.location
  tags     = merge({ "ResourceName" = format("%s", var.resource_group_name) }, var.tags, )
}

#-------------------------------------
# VNET Creation - Default is "true"
#-------------------------------------
resource "azurerm_virtual_network" "vnet" {
  name                = lower("vnet-${var.hub_vnet_name}-${local.location}")
  location            = local.location
  resource_group_name = local.resource_group_name
  address_space       = var.vnet_address_space
  dns_servers         = var.dns_servers
  tags                = merge({ "ResourceName" = lower("vnet-${var.hub_vnet_name}-${local.location}") }, var.tags, )

  dynamic "ddos_protection_plan" {
    for_each = local.if_ddos_enabled

    content {
      id     = azurerm_network_ddos_protection_plan.ddos[0].id
      enable = true
    }
  }
}

#--------------------------------------------
# Ddos protection plan - Default is "true"
#--------------------------------------------
resource "azurerm_network_ddos_protection_plan" "ddos" {
  count               = var.create_ddos_plan ? 1 : 0
  name                = lower("${var.hub_vnet_name}-ddos-protection-plan")
  resource_group_name = local.resource_group_name
  location            = local.location
  tags                = merge({ "ResourceName" = lower("${var.hub_vnet_name}-ddos-protection-plan") }, var.tags, )
}
resource "azurerm_resource_group" "nwatcher" {
  count    = var.create_network_watcher != false ? 1 : 0
  name     = "NetworkWatcherRG"
  location = local.location
  tags     = merge({ "ResourceName" = "NetworkWatcherRG" }, var.tags, )
}

#-------------------------------------
# Network Watcher - Default is "true"
#-------------------------------------
resource "azurerm_network_watcher" "nwatcher" {
  count               = var.create_network_watcher != false ? 1 : 0
  name                = "NetworkWatcher_${local.location}"
  location            = local.location
  resource_group_name = azurerm_resource_group.nwatcher.0.name
  tags                = merge({ "ResourceName" = format("%s", "NetworkWatcher_${local.location}") }, var.tags, )
}

#--------------------------------------------------------------------------------------------------------
# Subnets Creation with, private link endpoint/service network policies, service endpoints and Delegation.
#--------------------------------------------------------------------------------------------------------
resource "azurerm_subnet" "fw-snet" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = local.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.firewall_subnet_address_prefix #[cidrsubnet(element(var.vnet_address_space, 0), 10, 0)]
  service_endpoints    = var.firewall_service_endpoints
}

resource "azurerm_subnet" "gw_snet" {
  count                = var.gateway_subnet_address_prefix != null ? 1 : 0
  name                 = "GatewaySubnet"
  resource_group_name  = local.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.gateway_subnet_address_prefix #[cidrsubnet(element(var.vnet_address_space, 0), 8, 1)]
  service_endpoints    = ["Microsoft.Storage"]
}

resource "azurerm_subnet" "snet" {
  for_each             = var.subnets
  name                 = lower(format("snet-%s-${var.hub_vnet_name}-${local.location}", each.value.subnet_name))
  resource_group_name  = local.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = each.value.subnet_address_prefix
  service_endpoints    = lookup(each.value, "service_endpoints", [])
  # Applicable to the subnets which used for Private link endpoints or services 
  enforce_private_link_endpoint_network_policies = lookup(each.value, "enforce_private_link_endpoint_network_policies", null)
  enforce_private_link_service_network_policies  = lookup(each.value, "enforce_private_link_service_network_policies", null)

  dynamic "delegation" {
    for_each = lookup(each.value, "delegation", {}) != {} ? [1] : []
    content {
      name = lookup(each.value.delegation, "name", null)
      service_delegation {
        name    = lookup(each.value.delegation.service_delegation, "name", null)
        actions = lookup(each.value.delegation.service_delegation, "actions", null)
      }
    }
  }
}

#---------------------------------------------------------------
# Network security group - NSG created for every subnet in VNet
#---------------------------------------------------------------
resource "azurerm_network_security_group" "nsg" {
  for_each            = var.subnets
  name                = lower("nsg_${each.key}_in")
  resource_group_name = local.resource_group_name
  location            = local.location
  tags                = merge({ "ResourceName" = lower("nsg_${each.key}_in") }, var.tags, )
  dynamic "security_rule" {
    for_each = concat(lookup(each.value, "nsg_inbound_rules", []), lookup(each.value, "nsg_outbound_rules", []))
    content {
      name                       = security_rule.value[0] == "" ? "Default_Rule" : security_rule.value[0]
      priority                   = security_rule.value[1]
      direction                  = security_rule.value[2] == "" ? "Inbound" : security_rule.value[2]
      access                     = security_rule.value[3] == "" ? "Allow" : security_rule.value[3]
      protocol                   = security_rule.value[4] == "" ? "Tcp" : security_rule.value[4]
      source_port_range          = "*"
      destination_port_range     = security_rule.value[5] == "" ? "*" : security_rule.value[5]
      source_address_prefix      = security_rule.value[6] == "" ? element(each.value.subnet_address_prefix, 0) : security_rule.value[6]
      destination_address_prefix = security_rule.value[7] == "" ? element(each.value.subnet_address_prefix, 0) : security_rule.value[7]
      description                = "${security_rule.value[2]}_Port_${security_rule.value[5]}"
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "nsg-assoc" {
  for_each                  = var.subnets
  subnet_id                 = azurerm_subnet.snet[each.key].id
  network_security_group_id = azurerm_network_security_group.nsg[each.key].id
}

#-------------------------------------------------
# route_table to divert traffic through Firewall
#-------------------------------------------------
resource "azurerm_route_table" "rtout" {
  name                = "route-network-outbound"
  resource_group_name = local.resource_group_name
  location            = local.location
  tags                = merge({ "ResourceName" = "route-network-outbound" }, var.tags, )
}

resource "azurerm_subnet_route_table_association" "rtassoc" {
  for_each       = var.subnets
  subnet_id      = azurerm_subnet.snet[each.key].id
  route_table_id = azurerm_route_table.rtout.id
}

resource "azurerm_route" "rt" {
  name                   = lower("route-to-firewall-${var.hub_vnet_name}-${local.location}")
  resource_group_name    = var.resource_group_name
  route_table_name       = azurerm_route_table.rtout.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.fw.ip_configuration.0.private_ip_address
}

#----------------------------------------
# Private DNS Zone - Default is "true"
#----------------------------------------
resource "azurerm_private_dns_zone" "dz" {
  count               = var.private_dns_zone_name != null ? 1 : 0
  name                = var.private_dns_zone_name
  resource_group_name = local.resource_group_name
  tags                = merge({ "ResourceName" = format("%s", lower(var.private_dns_zone_name)) }, var.tags, )
}

resource "azurerm_private_dns_zone_virtual_network_link" "dzvlink" {
  count                 = var.private_dns_zone_name != null ? 1 : 0
  name                  = lower("${var.private_dns_zone_name}-link")
  resource_group_name   = local.resource_group_name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  private_dns_zone_name = azurerm_private_dns_zone.dz[0].name
  tags                  = merge({ "ResourceName" = format("%s", lower("${var.private_dns_zone_name}-link")) }, var.tags, )
}

#------------------------------------------
# Public IP resources for Azure Firewall
#------------------------------------------
resource "random_string" "str" {
  for_each = local.public_ip_map
  length   = 6
  special  = false
  upper    = false
  keepers = {
    domain_name_label = each.key
  }
}

resource "azurerm_public_ip_prefix" "pip_prefix" {
  name                = lower("${var.hub_vnet_name}-pip-prefix")
  location            = local.location
  resource_group_name = local.resource_group_name
  prefix_length       = 30
  tags                = merge({ "ResourceName" = lower("${var.hub_vnet_name}-pip-prefix") }, var.tags, )
}

resource "azurerm_public_ip" "fw-pip" {
  for_each            = local.public_ip_map
  name                = lower("pip-${var.hub_vnet_name}-${each.key}-${local.location}")
  location            = local.location
  resource_group_name = local.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  public_ip_prefix_id = azurerm_public_ip_prefix.pip_prefix.id
  domain_name_label   = format("%s%s", lower(replace(each.key, "/[[:^alnum:]]/", "")), random_string.str[each.key].result)
  tags                = merge({ "ResourceName" = lower("pip-${var.hub_vnet_name}-${each.key}-${local.location}") }, var.tags, )
}

#-----------------
# Azure Firewall 
#-----------------
resource "azurerm_firewall" "fw" {
  name                = lower("fw-${var.hub_vnet_name}-${local.location}")
  location            = local.location
  resource_group_name = local.resource_group_name
  zones               = var.firewall_zones
  tags                = merge({ "ResourceName" = lower("fw-${var.hub_vnet_name}-${local.location}") }, var.tags, )
  dynamic "ip_configuration" {
    for_each = local.public_ip_map
    iterator = ip
    content {
      name                 = ip.key
      subnet_id            = ip.key == var.public_ip_names[0] ? azurerm_subnet.fw-snet.id : null
      public_ip_address_id = azurerm_public_ip.fw-pip[ip.key].id
    }
  }
}

#----------------------------------------------
# Azure Firewall Network/Application/NAT Rules 
#----------------------------------------------
resource "azurerm_firewall_application_rule_collection" "fw_app" {
  for_each            = local.fw_application_rules
  name                = lower(format("fw-app-rule-%s-${var.hub_vnet_name}-${local.location}", each.key))
  azure_firewall_name = azurerm_firewall.fw.name
  resource_group_name = local.resource_group_name
  priority            = 100 * (each.value.idx + 1)
  action              = each.value.rule.action

  rule {
    name             = each.key
    source_addresses = each.value.rule.source_addresses
    target_fqdns     = each.value.rule.target_fqdns

    protocol {
      type = each.value.rule.protocol.type
      port = each.value.rule.protocol.port
    }
  }
}

resource "azurerm_firewall_network_rule_collection" "fw" {
  for_each            = local.fw_network_rules
  name                = lower(format("fw-net-rule-%s-${var.hub_vnet_name}-${local.location}", each.key))
  azure_firewall_name = azurerm_firewall.fw.name
  resource_group_name = local.resource_group_name
  priority            = 100 * (each.value.idx + 1)
  action              = each.value.rule.action

  rule {
    name                  = each.key
    source_addresses      = each.value.rule.source_addresses
    destination_ports     = each.value.rule.destination_ports
    destination_addresses = [for dest in each.value.rule.destination_addresses : contains(var.public_ip_names, dest) ? azurerm_public_ip.fw-pip[dest].ip_address : dest]
    protocols             = each.value.rule.protocols
  }
}

resource "azurerm_firewall_nat_rule_collection" "fw" {
  for_each            = local.fw_nat_rules
  name                = lower(format("fw-nat-rule-%s-${var.hub_vnet_name}-${local.location}", each.key))
  azure_firewall_name = azurerm_firewall.fw.name
  resource_group_name = local.resource_group_name
  priority            = 100 * (each.value.idx + 1)
  action              = each.value.rule.action

  rule {
    name                  = each.key
    source_addresses      = each.value.rule.source_addresses
    destination_ports     = each.value.rule.destination_ports
    destination_addresses = [for dest in each.value.rule.destination_addresses : contains(var.public_ip_names, dest) ? azurerm_public_ip.fw-pip[dest].ip_address : dest]
    protocols             = each.value.rule.protocols
    translated_address    = each.value.rule.translated_address
    translated_port       = each.value.rule.translated_port
  }
}
