# We strongly recommend using the required_providers block to set the
# Azure Provider source and version being used
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.81.0"
    }
  }
  backend "azurerm" {
    storage_account_name = "tfstatefk"
    container_name       = "tfstatefk"
    key = "storage.tfstate"
    resource_group_name = "RG-Fabian-Konrad"
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}

  #use_msi = true
  #...
}

data "azurerm_resource_group" "rg_fk" {
  name = "RG-Fabian-Konrad" # TODO: use variables here
}
