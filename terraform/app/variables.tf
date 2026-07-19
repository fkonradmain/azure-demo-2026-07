# Azure resource group name. Unfortunately, the provider does not allow defaulting the resource group, similar to defaulting the Subscription
variable "azure_rg_name" {
    type = string
    const = true
    description = "Name of the Azure Resource Group that is being used"
}

# Azure location, derive that from the rseource group
data "azurerm_resource_group" "app_rg" {
  name = var.azure_rg_name
}

# Current deployment stage, to allow multitenancy in the deployment
# This is used to flag if the environment is "dev", "prod" etc or anything of that sort
variable "app_stage" {
    type = string
    const = true
    description = "Name of the application stage that is currently being deployed"
    # default = "dev"
}
