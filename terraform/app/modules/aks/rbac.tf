# Create an identity for the AKS cluster itself and grant it network contributor rights to its own networks
resource "azurerm_user_assigned_identity" "aks_identity" {
  name                = "app-workload-aks-${var.app_stage}-${random_string.app_suffix.result}-identity"
  location            = var.azure_location
  resource_group_name = var.azure_rg_name
}

resource "azurerm_role_assignment" "aks_api_network_contributor" {
  scope                = var.subnets.aks_api.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks_identity.principal_id
}

resource "azurerm_role_assignment" "aks_node_network_contributor" {
  scope                = var.subnets.aks_node.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks_identity.principal_id
}

# Create identities for the workloads running in the cluster and grant them vault access rights
# The two identities are then mapped to specific service accounts in specific namespaces through identity federation
# privileged identity
resource "azurerm_user_assigned_identity" "aks_privileged_workload_identity" {
  name                = "${azurerm_kubernetes_cluster.workload_aks.name}-privileged-workload-identity"
  location            = var.azure_location
  resource_group_name = var.azure_rg_name
}

resource "azurerm_role_assignment" "aks_workload_vault_admin" {
 scope                = var.aks_keyvault_id
 role_definition_name = "Key Vault Secrets Officer"
 principal_id         = azurerm_user_assigned_identity.aks_privileged_workload_identity.principal_id
}

# unprivileged identity
resource "azurerm_user_assigned_identity" "aks_unprivileged_workload_identity" {
  name                = "${azurerm_kubernetes_cluster.workload_aks.name}-unprivileged-workload-identity"
  location            = var.azure_location
  resource_group_name = var.azure_rg_name
}

resource "azurerm_role_assignment" "aks_workload_vault_read" {
 scope                = var.aks_keyvault_id
 role_definition_name = "Key Vault Secrets User"
 principal_id         = azurerm_user_assigned_identity.aks_privileged_workload_identity.principal_id
}

# Retrieve Tenant ID for creating a vault access policy
data "azurerm_client_config" "current" {}

# Grant access to the keyvault via access policy
# TODO: check if this actually is a duplicate with the role assignment above
resource "azurerm_key_vault_access_policy" "aks_vault_access" {
  key_vault_id = var.aks_keyvault_id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.aks_identity.principal_id

  key_permissions = [
    "Backup", "Create", "Decrypt", "Delete", "Encrypt", "Get", "Import", "List", "Purge", "Recover", "Restore", "Sign", "UnwrapKey", "Update", "Verify", "WrapKey", "Release", "Rotate", "GetRotationPolicy", "SetRotationPolicy",
  ]

  secret_permissions = [
    "Backup", "Delete", "Get", "List", "Purge", "Recover", "Restore", "Set",
  ]
}

# Federate service account in the cluster
resource "azurerm_federated_identity_credential" "external_secrets_federated_credential" {
  name                      = "aks-federated-credential-external-secrets-${var.app_stage}"
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = azurerm_kubernetes_cluster.workload_aks.oidc_issuer_url
  user_assigned_identity_id = azurerm_user_assigned_identity.aks_identity.id
  subject                   = "system:serviceaccount:external-secrets:workload-identity-sa" # TODO: use variables for service account naming
}
