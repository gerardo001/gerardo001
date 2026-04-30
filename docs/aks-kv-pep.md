# AKS (kubenet) Pod -> Key Vault Secrets using Managed Identity + Private Endpoint (Private-only)

**Conversation date:** 2026-04-08  
**User login:** gerardo001

## What is an Azure Managed Identity?

An **Azure Managed Identity** is a Microsoft Entra ID identity that Azure creates and manages so workloads can authenticate to Azure services **without storing credentials** (no client secrets or certificates). You grant the identity permissions, and the workload obtains tokens to call Azure services such as **Azure Key Vault**.

Types:
- **System-assigned managed identity**: tied to one Azure resource; lifecycle follows that resource.
- **User-assigned managed identity (UAMI)**: standalone identity; can be reused across resources (commonly used for AKS workloads).

## How is it used for a Kubernetes pod to read Key Vault secrets?

Recommended approach on AKS: **AKS Workload Identity** (newer; replaces legacy AAD Pod Identity).

High-level flow:
1. Create a **User-Assigned Managed Identity (UAMI)**.
2. Grant the UAMI authorization to read Key Vault secrets (Azure RBAC recommended).
3. In AKS, enable **OIDC issuer** + **Workload Identity**.
4. Create a Kubernetes **ServiceAccount** and annotate it with the UAMI client ID.
5. Create a **Federated Identity Credential** on the UAMI that trusts that ServiceAccount (OIDC federation).
6. The pod uses that ServiceAccount; Azure issues tokens via federation; the pod calls Key Vault.

## How does a Key Vault Private Endpoint change things?

A **Key Vault Private Endpoint** changes the **network path**, not authentication:
- Authentication still uses Entra ID tokens (via Workload Identity / Managed Identity).
- Network traffic to the vault resolves to a **private IP** through **Private DNS** and stays on private networking.

For private-only:
- Configure Key Vault with **public network access disabled**.
- Ensure AKS nodes can resolve `privatelink.vaultcore.azure.net` and reach the private endpoint IP on TCP 443.

---

## Azure resources needed (kubenet + private-only Key Vault)

### Identity / Authorization
- **User-assigned managed identity (UAMI)** for the workload
- **AKS cluster** with:
  - `--enable-oidc-issuer`
  - `--enable-workload-identity`
  - network plugin: `kubenet`
- **Key Vault** (RBAC enabled)
- **Role assignment**: UAMI -> Key Vault role **Key Vault Secrets User**

### Networking / Private connectivity
- **Resource Group**: `rg-<app>-<env>-<region>`
- **VNet**: `vnet-<app>-<env>-<region>`
- Subnets:
  - `snet-aks-nodes` (AKS node subnet)
  - `snet-private-endpoints` (private endpoint subnet; recommended)
- **Private Endpoint** for Key Vault
- **Private DNS Zone**: `privatelink.vaultcore.azure.net`
- **Private DNS Zone Link** to the AKS VNet

### Kubernetes-side objects (required but not Azure resources)
- Kubernetes **Namespace**: `ns-<app>`
- Kubernetes **ServiceAccount**: `sa-<app>-kv-reader`
- Federated Identity Credential on UAMI:
  - issuer: AKS OIDC issuer URL
  - subject: `system:serviceaccount:<namespace>:<serviceaccount>`
  - audience: `api://AzureADTokenExchange`

---

## Generic naming convention

- Resource group: `rg-<app>-<env>-<region>`
- VNet: `vnet-<app>-<env>-<region>`
- AKS: `aks-<app>-<env>-<region>`
- Key Vault: `kv-<app>-<env>-<region>-<uniq>` (must be globally unique; 3-24 chars; alnum only)
- Identity: `uami-<app>-<env>-<region>-kvreader`
- Private endpoint: `pe-kv-<app>-<env>-<region>`
- Private DNS zone: `privatelink.vaultcore.azure.net`
- DNS link: `pdzlink-vaultcore-<app>-<env>-<region>`

---

## Infrastructure workflow: GitHub Actions (Azure CLI)

This workflow deploys:
- RG + VNet/subnets
- Key Vault (private-only) + private endpoint + private DNS
- UAMI + Key Vault role assignment
- AKS (kubenet) with workload identity
- K8s ServiceAccount + federated identity credential on the UAMI

### Required GitHub secrets (Azure auth)
- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

### Required GitHub variables
- `APP` (e.g., `myapp`)
- `ENV` (e.g., `dev`)
- `REGION` (e.g., `eastus`)

Create: `.github/workflows/infra-aks-kv-privateonly-kubenet.yml`

```yaml
on:
  workflow_dispatch:

permissions:
  id-token: write
  contents: read

env:
  APP: ${{ vars.APP }}
  ENV: ${{ vars.ENV }}
  REGION: ${{ vars.REGION }}

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Azure login (OIDC)
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Deploy infra
        uses: azure/cli@v2
        with:
          inlineScript: |
            set -euo pipefail

            app="${APP}"
            env="${ENV}"
            region="${REGION}"

            rg="rg-${app}-${env}-${region}"
            vnet="vnet-${app}-${env}-${region}"
            snet_nodes="snet-aks-nodes"
            snet_pe="snet-private-endpoints"

            aks="aks-${app}-${env}-${region}"
            uami="uami-${app}-${env}-${region}-kvreader"

            # Key Vault name must be globally unique and 3-24 chars, alnum only.
            uniq="$(cat /proc/sys/kernel/random/uuid | tr -d '-' | cut -c1-8)"
            kv="kv${app}${env}${region}${uniq}"
            kv="$(echo "${kv}" | tr -cd '[:alnum:]' | tr '[:upper:]' '[:lower:]' | cut -c1-24)"

            pe="pe-kv-${app}-${env}-${region}"

            dns_zone="privatelink.vaultcore.azure.net"
            dns_link="pdzlink-vaultcore-${app}-${env}-${region}"

            echo "RG=${rg}"
            echo "VNET=${vnet}"
            echo "AKS=${aks}"
            echo "UAMI=${uami}"
            echo "KV=${kv}"

            # 1) Resource Group
            az group create -n "${rg}" -l "${region}"

            # 2) VNet + subnets
            az network vnet create \
              -g "${rg}" -n "${vnet}" -l "${region}" \
              --address-prefixes 10.20.0.0/16 \
              --subnet-name "${snet_nodes}" --subnet-prefixes 10.20.1.0/24

            az network vnet subnet create \
              -g "${rg}" --vnet-name "${vnet}" -n "${snet_pe}" \
              --address-prefixes 10.20.2.0/24 \
              --disable-private-endpoint-network-policies true

            # 3) Key Vault (private-only)
            az keyvault create \
              -g "${rg}" -n "${kv}" -l "${region}" \
              --enable-rbac-authorization true \
              --public-network-access Disabled

            kv_id="$(az keyvault show -g "${rg}" -n "${kv}" --query id -o tsv)"

            # 4) Private DNS zone + link
            az network private-dns zone create -g "${rg}" -n "${dns_zone}"

            vnet_id="$(az network vnet show -g "${rg}" -n "${vnet}" --query id -o tsv)"
            az network private-dns link vnet create \
              -g "${rg}" -n "${dns_link}" \
              -z "${dns_zone}" \
              -v "${vnet_id}" \
              -e false

            # 5) Private endpoint for Key Vault + DNS zone group
            snet_pe_id="$(az network vnet subnet show -g "${rg}" --vnet-name "${vnet}" -n "${snet_pe}" --query id -o tsv)"

            az network private-endpoint create \
              -g "${rg}" -n "${pe}" -l "${region}" \
              --subnet "${snet_pe_id}" \
              --private-connection-resource-id "${kv_id}" \
              --group-ids vault \
              --connection-name "${pe}-conn"

            az network private-endpoint dns-zone-group create \
              -g "${rg}" --endpoint-name "${pe}" -n "kv-zonegroup" \
              --private-dns-zone "${dns_zone}" \
              --zone-name "${dns_zone}"

            # 6) Create User Assigned Managed Identity
            az identity create -g "${rg}" -n "${uami}" -l "${region}"
            uami_client_id="$(az identity show -g "${rg}" -n "${uami}" --query clientId -o tsv)"
            uami_principal_id="$(az identity show -g "${rg}" -n "${uami}" --query principalId -o tsv)"

            # 7) RBAC: allow UAMI to read secrets
            az role assignment create \
              --assignee-object-id "${uami_principal_id}" \
              --assignee-principal-type ServicePrincipal \
              --role "Key Vault Secrets User" \
              --scope "${kv_id}"

            # 8) AKS (kubenet) with Workload Identity + OIDC
            snet_nodes_id="$(az network vnet subnet show -g "${rg}" --vnet-name "${vnet}" -n "${snet_nodes}" --query id -o tsv)"

            az aks create \
              -g "${rg}" -n "${aks}" -l "${region}" \
              --node-count 2 \
              --network-plugin kubenet \
              --vnet-subnet-id "${snet_nodes_id}" \
              --enable-oidc-issuer \
              --enable-workload-identity \
              --generate-ssh-keys

            az aks get-credentials -g "${rg}" -n "${aks}" --overwrite-existing

            # 9) K8s ServiceAccount for KV access
            namespace="ns-${app}"
            sa="sa-${app}-kv-reader"

            kubectl create namespace "${namespace}" --dry-run=client -o yaml | kubectl apply -f -

            cat <<EOF | kubectl apply -f -
            apiVersion: v1
            kind: ServiceAccount
            metadata:
              name: ${sa}
              namespace: ${namespace}
              annotations:
                azure.workload.identity/client-id: "${uami_client_id}"
            EOF

            # 10) Create federated identity credential on the UAMI
            issuer="$(az aks show -g "${rg}" -n "${aks}" --query "oidcIssuerProfile.issuerUrl" -o tsv)"
            subject="system:serviceaccount:${namespace}:${sa}"

            az identity federated-credential create \
              --name "fic-${app}-${env}-kv" \
              --identity-name "${uami}" \
              --resource-group "${rg}" \
              --issuer "${issuer}" \
              --subject "${subject}" \
              --audiences "api://AzureADTokenExchange"

            echo "Done."
            echo "Key Vault: ${kv}"
            echo "Namespace: ${namespace}"
            echo "ServiceAccount: ${sa}"
            echo "UAMI clientId: ${uami_client_id}"
```

---

## Notes / gotchas for kubenet + private-only

1. **DNS resolution is critical**: the AKS nodes must resolve Key Vault to the private endpoint via `privatelink.vaultcore.azure.net`.
2. **Private-only means your laptop can’t test it** unless you are on the VNet (VPN/ExpressRoute) and using the private DNS.
3. If you plan to mount secrets into pods, consider adding:
   - Secrets Store CSI Driver
   - Azure Key Vault provider
   - `SecretProviderClass` + pod spec using the ServiceAccount above

---

## Next steps (optional)
- Add Kubernetes manifests to mount secrets via Secrets Store CSI driver
- Add a sample app that reads a secret using Azure SDK + Workload Identity

ref: https://github.com/copilot/c/2af4b228-4794-4942-8705-117ffea2ce93