terraform {
  backend "azurerm" {
    resource_group_name  = "rg-aksdemo-tfstate"
    storage_account_name = "staksdemostate"
    container_name       = "tfstate"
    key                  = "dev.terraform.tfstate"
  }
}
