# Unique random string to allow collission free keyvault generation
resource "random_string" "app_suffix" {
 length  = 5
 special = false
 upper   = false
}
# Get current AzureRM client config. This is needed to retrieve the tenant id
data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "aks_keyvault" {
  name                = "aks-keyvault-${var.app_stage}-${random_string.app_suffix.result}"
  location            = var.azure_location
  resource_group_name = var.azure_rg_name
  sku_name            = "standard"
  tenant_id           = data.azurerm_client_config.current.tenant_id

  # Additional optional features for the key vault:
  # enabled_for_deployment = true
  # enabled_for_disk_encryption = true
  # enabled_for_template_deployment = true

  # TODO: check if we really need to enable RBAC on the key vault
  rbac_authorization_enabled = true

  # Set some default access policies for the vault, we do not do that because we use azure rbac
  # access_policy {}

  # Limit network acess to the vault only to the assigned users
  # TODO: configure vault network acls correctly
  network_acls {
    default_action = "Allow" # TODO: revert to "Deny"
    # TODO: check if we should really allow azureservices to bypass
    bypass = "AzureServices"

    # TODO: set up ip rules for limiting the network access for the aks vault
    # ip_rules = []
  }
}

# TODO: this is only an interim role to give all employees vault access. Remove it after testing
# resource "azurerm_role_assignment" "local_user_vault_admin" {
#  scope                = azurerm_key_vault.aks_keyvault.id
#  role_definition_name = "Key Vault Secrets Officer"
#  principal_id         = "90bab22c-b512-44b9-aff4-9b787893291a" # All users user group
# }

resource "azurerm_private_endpoint" "keyvault_endpoint" {
  name                = "keyvault-endpoint-${var.app_stage}"
  location            = var.azure_location
  resource_group_name = var.azure_rg_name
  subnet_id           = var.subnets.private_endpoints.id

  private_service_connection {
    name              = "keyvault-psc-${var.app_stage}"
    subresource_names = ["vault"]
    # private_connection_resource_alias = azurerm_private_link_service.keyvault_privatelink.alias
    private_connection_resource_id = azurerm_key_vault.aks_keyvault.id
    is_manual_connection           = false #TODO: we might actually need manual approval, in that case set to true
  }


  private_dns_zone_group {
    name                 = "keyvault-dns-zone-group-${var.app_stage}"
    private_dns_zone_ids = [var.private_endpoints_dns_zone_id]
  }
}
