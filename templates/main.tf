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

  resource_group_name = var.resource_group_name
  location            = var.location
}
