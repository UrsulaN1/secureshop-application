#!/usr/bin/env bash
# US-036: store application secrets in Vault (never in Git/source code)
set -euo pipefail
vault kv put secret/secureshop/dev/db \
  username="secureshop_app" \
  password="$(openssl rand -base64 24)"
