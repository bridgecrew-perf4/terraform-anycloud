variable "resource_group_name" {
  default = "%%RG_NAME%%"
}
variable "location" {
  default = "%%LOC%%"
}
variable "hub_vnet_name" {
  default = "%%HUB%%"
}
variable "vnet_address_space" {
  default = ["%%CIDR%%"]
}
variable "create_ddos_plan" {
  default = false
}
variable "dns_servers" {
  default = "%%DNS%%"
}