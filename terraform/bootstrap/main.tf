# import {
#   id = "${data.azurerm_resource_group.rg_fk.id}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/fk-github-terraform"
#   to = azurerm_user_assigned_identity.fk_github_terraform
# }

resource "azurerm_user_assigned_identity" "fk_github_terraform" {
  location            = data.azurerm_resource_group.rg_fk.location
  name                = "fk-github-terraform"
  resource_group_name = data.azurerm_resource_group.rg_fk.name
}

resource "azurerm_role_assignment" "github_contributor_access" {
  scope                = data.azurerm_resource_group.rg_fk.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.fk_github_terraform.principal_id
}

# import {
#   id = "${azurerm_user_assigned_identity.fk_github_terraform.id}/federatedIdentityCredentials/fk-github-terraform"
#   to = azurerm_federated_identity_credential.fk_github_terraform
# }

# Federate user assigned identity with GitHub repo
resource "azurerm_federated_identity_credential" "fk_github_terraform" {
  name                      = "fk-github-terraform"
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = "https://token.actions.githubusercontent.com"
  user_assigned_identity_id = azurerm_user_assigned_identity.fk_github_terraform.id
  subject                   = "repo:fkonradmain/azure-demo-2026-07:ref:refs/heads/master"
}

# TF state store
import {
  id = "${data.azurerm_resource_group.rg_fk.id}/providers/Microsoft.Storage/storageAccounts/tfstatefk"
  to = azurerm_storage_account.tfstatefk
}

resource "azurerm_storage_account" "tfstatefk" {
  lifecycle {
    prevent_destroy = true
  }
  name                     = "tfstatefk"
  resource_group_name      = data.azurerm_resource_group.rg_fk.name
  location                 = data.azurerm_resource_group.rg_fk.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  allow_nested_items_to_be_public = false
}

# import {
#   id = "${azurerm_storage_account.tfstatefk.id}/blobServices/default/containers/tfstatefk"
#   to = azurerm_storage_container.tfstatefk
# }

resource "azurerm_storage_container" "tfstatefk" {
  lifecycle {
    prevent_destroy = true
  }
  name                  = "tfstatefk"
  storage_account_id    = azurerm_storage_account.tfstatefk.id
  container_access_type = "private"
}

# import {
#   id = "https://tfstatefk.blob.core.windows.net/tfstatefk/bootstrap.tfstate"
#   to = azurerm_storage_blob.tfstatefk
# }
# 
# resource "azurerm_storage_blob" "tfstatefk" {
#   name                   = "bootstrap.tfstate"
#   type                   = "Block"
#   storage_container_id = azurerm_storage_container.tfstatefk.id
#   source                 = "${path.module}/terraform.tfstate"
# }
