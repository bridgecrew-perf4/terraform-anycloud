variable "project_name" {
  default = "anycloud"
}
variable "environment" {
  default = "demo"
}
variable "owner" {
  default = "olivier.vermeir@ignyte.be"
}
variable "resource_group_name" {
  default = "ignyte-rg-networking"
}
variable "location" {
  default = "westeurope"
}
variable "hub_vnet_name" {
  default = "ignyte-hub"
}
variable "vnet_address_space" {
  default = ["10.1.0.0/16"]
}
variable "create_ddos_plan" {
  default = true
}
variable "dns_servers" {
  default = []
}
variable "create_network_watcher" {
  default = false
}
variable "firewall_subnet_address_prefix" {
  default = ["10.1.0.0/26"]
}
variable "gateway_subnet_address_prefix" {
  default = ["10.1.1.0/27"]
}
variable "private_dns_zone_name" {
  default = "publiccloud.ignyte.be"
}
