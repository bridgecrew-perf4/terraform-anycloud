output "resource_group_name" {
  description = "The name of the resource group in which resources are created"
  value       = module.vnet-hub.resource_group_name
}

output "resource_group_id" {
  description = "The id of the resource group in which resources are created"
  value       = module.vnet-hub.resource_group_id
}

output "resource_group_location" {
  description = "The location of the resource group in which resources are created"
  value       = module.vnet-hub.resource_group_location
}
