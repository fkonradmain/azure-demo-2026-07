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

# Get the zone ID for the private endpoints dns zone
# variable "private_endpoints_dns_zone_id" {
#     type = string
# }

# Get the map of all subnets
variable "subnets" {
  type = map(map(string))
}

# Get the key vault id
variable "aks_keyvault_id" {
  type = string
}
