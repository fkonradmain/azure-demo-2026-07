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
  name                = "${azurerm_kubernetes_cluster.workload_aks.name}-privileged-identity"
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
  name                = "${azurerm_kubernetes_cluster.workload_aks.name}-unprivileged-identity"
  location            = var.azure_location
  resource_group_name = var.azure_rg_name
}

resource "azurerm_role_assignment" "aks_workload_vault_read" {
  scope                = var.aks_keyvault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.aks_unprivileged_workload_identity.principal_id
}

locals {
  privileged_namespaces   = ["kube-system", "kube-node-lease", "external-secrets"]
  unprivileged_namespaces = ["default", "demo", "kube-public"]
  service_account_name    = "workload-identity-sa"
}

# Federate privileged service accounts in the cluster
resource "azurerm_federated_identity_credential" "privileged_sa_federated_credential" {
  for_each                  = { for _, item in local.privileged_namespaces : item => item }
  name                      = "aks-privileged-federated-credential-${each.value}-${var.app_stage}"
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = azurerm_kubernetes_cluster.workload_aks.oidc_issuer_url
  user_assigned_identity_id = azurerm_user_assigned_identity.aks_privileged_workload_identity.id
  subject                   = "system:serviceaccount:${each.value}:${local.service_account_name}"
}

# Federate unprivileged service accounts in the cluster
resource "azurerm_federated_identity_credential" "unprivileged_sa_federated_credential" {
  for_each                  = { for _, item in local.unprivileged_namespaces : item => item }
  name                      = "aks-unprivileged-federated-credential-${each.value}-${var.app_stage}"
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = azurerm_kubernetes_cluster.workload_aks.oidc_issuer_url
  user_assigned_identity_id = azurerm_user_assigned_identity.aks_unprivileged_workload_identity.id
  subject                   = "system:serviceaccount:${each.value}:${local.service_account_name}"
}

# TODO: Deloy the respective "workload-identity-sa" kubernetes service accounts in the namespaces for which these roles have just been assigned
