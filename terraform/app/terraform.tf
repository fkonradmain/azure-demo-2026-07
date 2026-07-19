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
    key = "dev.tfstate" # TODO: allow using stage variables for the name of the terraform state file
    resource_group_name = "RG-Fabian-Konrad"
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}

  #use_msi = true
  #...
}
