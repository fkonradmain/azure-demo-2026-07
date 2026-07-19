# Azure resource group name.
variable "azure_rg_name" {
    type = string
}

# Azure location, derive that from the rseource group
variable "azure_location" {
    type = string
}

# Current deployment stage, to allow multitenancy in the deployment
variable "app_stage" {
    type = string
}
