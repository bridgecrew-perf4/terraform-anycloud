terraform {
  backend "azurerm" {
    resource_group_name  = "tfstate"
    storage_account_name = "ignytebetfstate"
    container_name       = "tfstate"
    key                  = "terraform.state"
  }
}

module "vnet-hub" {
  source = "../../../modules/vnet-hub"

  resource_group_name            = var.resource_group_name
  location                       = var.location
  hub_vnet_name                  = var.hub_vnet_name
  vnet_address_space             = var.vnet_address_space
  dns_servers                    = var.dns_servers
  create_ddos_plan               = var.create_ddos_plan
  create_network_watcher         = var.create_network_watcher
  firewall_subnet_address_prefix = var.firewall_subnet_address_prefix
  gateway_subnet_address_prefix  = var.gateway_subnet_address_prefix
  private_dns_zone_name          = var.private_dns_zone_name

  subnets = {
    mgmt_subnet = {
      subnet_name           = "management"
      subnet_address_prefix = ["10.1.2.0/24"]
      service_endpoints     = ["Microsoft.Storage"]
      nsg_inbound_rules = [
        ["rdp", "100", "Inbound", "Allow", "Tcp", "3389", "*", ""],
        ["ssh", "200", "Inbound", "Allow", "Tcp", "22", "*", ""]
      ]
      nsg_outbound_rules = [
        ["ntp_out", "300", "Outbound", "Allow", "Udp", "123", "", "0.0.0.0/0"]
      ]
    }
    app_subnet = {
      subnet_name           = "applications"
      subnet_address_prefix = ["10.1.3.0/24"]
      service_endpoints     = ["Microsoft.Storage"]
      nsg_inbound_rules = [
        ["rdp", "100", "Inbound", "Allow", "Tcp", "3389", "*", ""]
      ]
      nsg_outbound_rules = [
        ["ntp_out", "300", "Outbound", "Allow", "Udp", "123", "", "0.0.0.0/0"]
      ]
    }
  }

  firewall_zones = [1, 2, 3]

  firewall_application_rules = [
    {
      name             = "microsoft"
      action           = "Allow"
      source_addresses = ["10.0.0.0/8"]
      target_fqdns     = ["*.microsoft.com"]
      protocol = {
        type = "Http"
        port = "80"
      }
    },
  ]

  firewall_network_rules = [
    {
      name                  = "ntp"
      action                = "Allow"
      source_addresses      = ["10.0.0.0/8"]
      destination_ports     = ["123"]
      destination_addresses = ["*"]
      protocols             = ["UDP"]
    },
    {
      name                  = "rdp"
      action                = "Allow"
      source_addresses      = ["*"]
      destination_ports     = ["3389"]
      destination_addresses = ["10.1.2.0/24"]
      protocols             = ["TCP"]
    }
  ]

  firewall_nat_rules = [
    {
      name                  = "testrule"
      action                = "Dnat"
      source_addresses      = ["10.0.0.0/8"]
      destination_ports     = ["53", ]
      destination_addresses = ["fw-public"]
      translated_port       = 53
      translated_address    = "8.8.8.8"
      protocols             = ["TCP", "UDP", ]
    },
    {
      name                  = "rdpnat"
      action                = "Dnat"
      source_addresses      = ["*"]
      destination_ports     = ["3389", ]
      destination_addresses = ["fw-public"]
      translated_port       = 3389
      translated_address    = "10.1.2.4"
      protocols             = ["TCP", "UDP", ]
    }
  ]

  tags = {
    ProjectName  = var.project_name
    Env          = var.environment
    owner        = var.owner
    BusinessUnit = "CORP"
  }
}
