#!/usr/bin/env bash
# US-043: deployment rollback helper
# Usage: ./rollback.sh <environment>  e.g. ./rollback.sh dev
set -euo pipefail
ENV="${1:?Usage: rollback.sh <environment>}"

echo "Current ArgoCD app history for secureshop-${ENV}:"
argocd app history "secureshop-${ENV}"

read -rp "Enter the revision ID to roll back to: " REVISION
argocd app rollback "secureshop-${ENV}" "$REVISION"

echo "Waiting for rollback to become healthy..."
argocd app wait "secureshop-${ENV}" --health --timeout 180

echo "Rollback complete. Current status:"
argocd app get "secureshop-${ENV}"
