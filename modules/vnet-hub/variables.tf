variable "create_resource_group" {
  default = true
}
variable "resource_group_name" {
  default = ""
}
variable "location" {
  default = ""
}
variable "hub_vnet_name" {
  default = ""
}
variable "vnet_address_space" {
  default = ["10.0.0.0/16"]
}
variable "create_ddos_plan" {
  default = false
}
variable "dns_servers" {
  default = []
}
variable "tags" {
  type    = map(string)
  default = {}
}
variable "create_network_watcher" {
  default = true
}
variable "subnets" {
  default = {}
}
variable "private_dns_zone_name" {
  description = "The name of the Private DNS zone"
  default     = null
}

variable "log_analytics_workspace_sku" {
  description = "The Sku of the Log Analytics Workspace. Possible values are Free, PerNode, Premium, Standard, Standalone, Unlimited, and PerGB2018"
  default     = "PerGB2018"
}

variable "log_analytics_logs_retention_in_days" {
  description = "The log analytics workspace data retention in days. Possible values range between 30 and 730."
  default     = 30
}

variable "nsg_diag_logs" {
  description = "NSG Monitoring Category details for Azure Diagnostic setting"
  default     = ["NetworkSecurityGroupEvent", "NetworkSecurityGroupRuleCounter"]
}
variable "firewall_service_endpoints" {
  description = "Service endpoints to add to the firewall subnet"
  type        = list(string)
  default = [
    "Microsoft.AzureActiveDirectory",
    "Microsoft.AzureCosmosDB",
    "Microsoft.EventHub",
    "Microsoft.KeyVault",
    "Microsoft.ServiceBus",
    "Microsoft.Sql",
    "Microsoft.Storage",
  ]
}
variable "public_ip_names" {
  description = "Public ips is a list of ip names that are connected to the firewall. At least one is required."
  type        = list(string)
  default     = ["fw-public"]
}

variable "gateway_subnet_address_prefix" {
  description = "The address prefix to use for the gateway subnet"
  default     = null
}

variable "firewall_subnet_address_prefix" {
  description = "The address prefix to use for the Firewall subnet"
  default     = []
}

variable "firewall_zones" {
  description = "A collection of availability zones to spread the Firewall over"
  type        = list(string)
  default     = null
}

variable "firewall_application_rules" {
  description = "List of application rules to apply to firewall."
  type        = list(object({ name = string, action = string, source_addresses = list(string), target_fqdns = list(string), protocol = object({ type = string, port = string }) }))
  default     = []
}

variable "firewall_network_rules" {
  description = "List of network rules to apply to firewall."
  type        = list(object({ name = string, action = string, source_addresses = list(string), destination_ports = list(string), destination_addresses = list(string), protocols = list(string) }))
  default     = []
}

variable "firewall_nat_rules" {
  description = "List of nat rules to apply to firewall."
  type        = list(object({ name = string, action = string, source_addresses = list(string), destination_ports = list(string), destination_addresses = list(string), protocols = list(string), translated_address = string, translated_port = string }))
  default     = []
}

variable "fw_pip_diag_logs" {
  description = "Firewall Public IP Monitoring Category details for Azure Diagnostic setting"
  default     = ["DDoSProtectionNotifications", "DDoSMitigationFlowLogs", "DDoSMitigationReports"]
}

variable "fw_diag_logs" {
  description = "Firewall Monitoring Category details for Azure Diagnostic setting"
  default     = ["AzureFirewallApplicationRule", "AzureFirewallNetworkRule", "AzureFirewallDnsProxy"]
}