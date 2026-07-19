#!/bin/bash
set -euo pipefail
# Proceeding according to https://azure.github.io/azure-workload-identity/docs/quick-start.html#quick-start

# 1 Install Mutating admission webhook
# Set Azure specific environment variables
# TENANT_ID="b2748d0a-856e-4184-bda8-831f9ffa8a48"
AZ_CLUSTER_NAME="app-workload-aks-dev-fgil1"
RESOURCE_GROUP="RG-Fabian-Konrad"
# LOCATION="westeurope"

# Register kubeconfig
az aks get-credentials -n "${AZ_CLUSTER_NAME}" -g "${RESOURCE_GROUP}" --overwrite-existing

AZURE_TENANT_ID="$(az account show --query tenantId -otsv)"

helm repo add azure-workload-identity https://azure.github.io/azure-workload-identity/charts
helm repo add external-secrets https://charts.external-secrets.io
helm repo update
# The mutating webhook helm install might fail, if so, we can skip this step
helm upgrade workload-identity-webhook azure-workload-identity/workload-identity-webhook \
    --namespace azure-workload-identity-system \
    --create-namespace \
    --set azureTenantID="${AZURE_TENANT_ID}" \
    --install \
    --rollback-on-failure || true

# 2. Export environment variables

# environment variables for the Azure Key Vault resource
KEYVAULT_NAME="aks-keyvault-dev-2nyds"

# environment variables for the user-assigned managed identity
#USER_ASSIGNED_IDENTITY_NAME="${AZ_CLUSTER_NAME}-unprivileged-identity"
USER_ASSIGNED_IDENTITY_NAME="${AZ_CLUSTER_NAME}-privileged-identity"

# environment variables for the Kubernetes service account & federated identity credential
#SERVICE_ACCOUNT_NAMESPACE="default"
SERVICE_ACCOUNT_NAMESPACE="external-secrets"
SERVICE_ACCOUNT_NAME="workload-identity-sa"

# 4. Create an AAD application or user-assigned managed identity and grant permissions to access the secret
USER_ASSIGNED_IDENTITY_CLIENT_ID="$(az identity show --name "${USER_ASSIGNED_IDENTITY_NAME}" --resource-group "${RESOURCE_GROUP}" --query 'clientId' -otsv)"
# USER_ASSIGNED_IDENTITY_OBJECT_ID="$(az identity show --name "${USER_ASSIGNED_IDENTITY_NAME}" --resource-group "${RESOURCE_GROUP}" --query 'principalId' -otsv)"
# az keyvault set-policy --name "${KEYVAULT_NAME}" \
#   --secret-permissions get \
#   --object-id "${USER_ASSIGNED_IDENTITY_OBJECT_ID}"

# 5. Create a Kubernetes service account
kubectl get ns "${SERVICE_ACCOUNT_NAMESPACE}" -o name || kubectl create ns "${SERVICE_ACCOUNT_NAMESPACE}"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  annotations:
    azure.workload.identity/client-id: "${APPLICATION_CLIENT_ID:-$USER_ASSIGNED_IDENTITY_CLIENT_ID}"
    azure.workload.identity/tenant-id: "${AZURE_TENANT_ID}"
  name: "${SERVICE_ACCOUNT_NAME}"
  namespace: "${SERVICE_ACCOUNT_NAMESPACE}"
EOF

# If the AAD application or user-assigned managed identity is not in the same tenant as the default tenant defined during installation, then annotate the service account with the application or user-assigned managed identity tenant ID:
# kubectl annotate sa ${SERVICE_ACCOUNT_NAME} -n ${SERVICE_ACCOUNT_NAMESPACE} azure.workload.identity/tenant-id="${AZURE_TENANT_ID}" --overwrite

# 6. Establish federated identity credential between the identity and the service account issuer & subject
# This is done via terraform

# 7. Deploy workload
# Install External Secrets Operator
helm upgrade external-secrets \
    external-secrets/external-secrets \
    -n external-secrets \
    --create-namespace \
    --install \
    --rollback-on-failure

# ClusterSecretStore
cat <<EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1
kind: ClusterSecretStore
metadata:
  name: azure-store
  namespace: external-secrets
spec:
  provider:
    azurekv:
      # URL of your Key Vault instance, see: https://docs.microsoft.com/en-us/azure/key-vault/general/about-keys-secrets-certificates
      authType: WorkloadIdentity
      vaultUrl: "https://${KEYVAULT_NAME}.vault.azure.net"
      # environmentType: PublicCloud
      # or alternatively "PrivateCloud" ??
      serviceAccountRef:
        name: "${SERVICE_ACCOUNT_NAME}"
        # namespace: external-secrets
      useAzureSDK: true
EOF
