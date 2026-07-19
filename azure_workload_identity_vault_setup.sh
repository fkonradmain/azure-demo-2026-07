#!/bin/bash
set -xeuo pipefail
# Proceeding according to https://azure.github.io/azure-workload-identity/docs/quick-start.html#quick-start

# 1 Install Mutating admission webhook
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
# Azure specific environment variables
AZ_CLUSTER_NAME="workload-aks"
# TENANT_ID="b2748d0a-856e-4184-bda8-831f9ffa8a48"

# environment variables for the Azure Key Vault resource
KEYVAULT_NAME="aks-keyvault-fk"
# export KEYVAULT_SECRET_NAME="my-secret"
RESOURCE_GROUP="RG-Fabian-Konrad"
# LOCATION="westeurope"

# environment variables for the AAD application
# [OPTIONAL] Only set this if you're using a Azure AD Application as part of this tutorial
# export APPLICATION_NAME="<your application name>"

# environment variables for the user-assigned managed identity
# [OPTIONAL] Only set this if you're using a user-assigned managed identity as part of this tutorial
USER_ASSIGNED_IDENTITY_NAME="aks_identity"

# environment variables for the Kubernetes service account & federated identity credential
SERVICE_ACCOUNT_NAMESPACE="external-secrets"
SERVICE_ACCOUNT_NAME="workload-identity-sa"
SERVICE_ACCOUNT_ISSUER="$(az aks show --name "${AZ_CLUSTER_NAME}" --query "oidcIssuerProfile.issuerUrl" -otsv)" # see section 1.1 on how to get the service account issuer url

# 4. Create an AAD application or user-assigned managed identity and grant permissions to access the secret
USER_ASSIGNED_IDENTITY_CLIENT_ID="$(az identity show --name "${USER_ASSIGNED_IDENTITY_NAME}" --resource-group "${RESOURCE_GROUP}" --query 'clientId' -otsv)"
USER_ASSIGNED_IDENTITY_OBJECT_ID="$(az identity show --name "${USER_ASSIGNED_IDENTITY_NAME}" --resource-group "${RESOURCE_GROUP}" --query 'principalId' -otsv)"
# az keyvault set-policy --name "${KEYVAULT_NAME}" \
#   --secret-permissions get \
#   --object-id "${USER_ASSIGNED_IDENTITY_OBJECT_ID}"

# 5. Create a Kubernetes service account

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  annotations:
    azure.workload.identity/client-id: ${APPLICATION_CLIENT_ID:-$USER_ASSIGNED_IDENTITY_CLIENT_ID}
  name: ${SERVICE_ACCOUNT_NAME}
  namespace: ${SERVICE_ACCOUNT_NAMESPACE}
EOF

# If the AAD application or user-assigned managed identity is not in the same tenant as the default tenant defined during installation, then annotate the service account with the application or user-assigned managed identity tenant ID:
kubectl annotate sa ${SERVICE_ACCOUNT_NAME} -n ${SERVICE_ACCOUNT_NAMESPACE} azure.workload.identity/tenant-id="${AZURE_TENANT_ID}" --overwrite

# 6. Establish federated identity credential between the identity and the service account issuer & subject
# This is done via terraform
# az identity federated-credential create \
#   --name "kubernetes-federated-credential" \
#   --identity-name "${USER_ASSIGNED_IDENTITY_NAME}" \
#   --resource-group "${RESOURCE_GROUP}" \
#   --issuer "${SERVICE_ACCOUNT_ISSUER}" \
#   --subject "system:serviceaccount:${SERVICE_ACCOUNT_NAMESPACE}:${SERVICE_ACCOUNT_NAME}"

# 7. Deploy workload
# Install External Secrets CRDs
kubectl apply -f "https://raw.githubusercontent.com/external-secrets/external-secrets/v2.8.0/deploy/crds/bundle.yaml" --server-side

# Then install External Secrets Operator
helm upgrade external-secrets \
   external-secrets/external-secrets \
    -n external-secrets \
    --create-namespace \
    --set installCRDs=false \
    --install \
    --rollback-on-failure

# ClusterSecretStore
cat <<EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1
kind: ClusterSecretStore
metadata:
  name: azure-store
  namespace: ${SERVICE_ACCOUNT_NAMESPACE}
spec:
  provider:
    azurekv:
      # URL of your Key Vault instance, see: https://docs.microsoft.com/en-us/azure/key-vault/general/about-keys-secrets-certificates
      authType: WorkloadIdentity
      vaultUrl: "https://${KEYVAULT_NAME}.vault.azure.net"
      # environmentType: PublicCloud
      # or alternatively "PrivateCloud" ??
      serviceAccountRef:
        name: workload-identity-sa
      useAzureSDK: true
EOF
