#!/usr/bin/env bash
# US-037: Integrate Kubernetes workloads with Vault (Kubernetes auth method)
set -euo pipefail

VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
export VAULT_ADDR

vault auth enable kubernetes || true

vault write auth/kubernetes/config \
  kubernetes_host="https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_SERVICE_PORT"

vault policy write secureshop-app secureshop-app-policy.hcl

vault write auth/kubernetes/role/secureshop \
  bound_service_account_names=secureshop \
  bound_service_account_namespaces=secureshop \
  policies=secureshop-app \
  ttl=1h

echo "Vault Kubernetes auth configured for the 'secureshop' service account."
