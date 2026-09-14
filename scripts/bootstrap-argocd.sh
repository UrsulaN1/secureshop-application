#!/usr/bin/env bash
# US-041: Deploy ArgoCD to EKS
set -euo pipefail

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for ArgoCD server to be ready..."
kubectl -n argocd rollout status deployment/argocd-server --timeout=180s

echo "Initial admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo

echo "Registering SecureShop ArgoCD Applications..."
kubectl apply -f ../gitops/apps/secureshop-dev.yaml
kubectl apply -f ../gitops/apps/secureshop-staging.yaml
kubectl apply -f ../gitops/apps/secureshop-prod.yaml
