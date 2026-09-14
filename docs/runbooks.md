# SecureShop Operational Runbooks (US-060)

## 1. Pipeline Failure Runbook
1. Open the failed run in **GitHub Actions**.
2. Identify which gate failed: `secret-scan`, `build-test-scan`, or `terraform-security` (ci.yml),
   or `build-scan-sign-push` (cd.yml).
3. Common causes and fixes:
   - **GitGuardian** flag → rotate the exposed credential immediately, purge it from Git history, re-push.
   - **JUnit failure** → reproduce locally with `mvn test`, fix the regression.
   - **SonarQube quality gate** → open the Sonar project dashboard, address blocker/critical issues.
   - **OWASP Dependency-Check** → upgrade the flagged dependency, or add a documented, approved suppression.
   - **Trivy critical CVE** → rebuild from an updated base image, or patch the affected package.
   - **Checkov** → fix the Terraform misconfiguration, or add a documented `skip-check`.
4. Re-run the workflow once fixed.

## 2. Kubernetes Failure Runbook
1. `kubectl get pods -n secureshop` — identify pods not in `Running`/`Ready`.
2. `kubectl describe pod <pod> -n secureshop` — check events (image pull errors, Kyverno policy rejection, resource limits).
3. `kubectl logs <pod> -n secureshop` — check application-level errors (cross-reference with Loki/Grafana).
4. If a Kyverno policy is blocking a legitimate deployment, review `k8s/kyverno/*.yaml` and confirm the workload spec meets the policy (non-root, resource limits, signed image, no `:latest`).
5. If nodes are unhealthy, check `kubectl get nodes` and the EKS managed node group in the AWS console.

## 3. Application Rollback Runbook
See `scripts/rollback.sh` (US-043).
1. `argocd app history secureshop-<env>`
2. Identify the last known-good revision.
3. `argocd app rollback secureshop-<env> <revision>`
4. Validate health: `argocd app get secureshop-<env>` and check Grafana dashboards for error-rate recovery.

## 4. Security Incident Runbook
1. **Falco alert fires** → check `#secureshop-alerts` Slack channel for context (pod, container, command).
2. Isolate: `kubectl cordon <node>` and/or delete the affected pod to stop the workload.
3. Preserve evidence: export pod logs and the Falco event before deleting resources.
4. Rotate any credentials the workload had access to via Vault (`vault kv put ...`) — assume compromise.
5. Root-cause: correlate with recent deployments (ArgoCD history) and CI pipeline runs (image provenance via Cosign/SBOM).
6. Document the incident and any policy/rule changes made in response.

## 5. Monitoring / Alert Troubleshooting Runbook
1. Alert fires in Slack (`#secureshop-alerts`) via Alertmanager.
2. Open Grafana → SecureShop Overview dashboard to see the underlying metric.
3. Cross-reference with Loki logs for the same time window and namespace.
4. If the alert is a false positive, tune the `PrometheusRule` threshold in `monitoring/secureshop-alert-rules.yaml` and re-apply — document why.

## 6. Secrets Rotation Procedure (US-036)
1. Generate a new credential (e.g. new DB password).
2. `vault kv put secret/secureshop/<env>/db username=... password=...`
3. Restart the affected deployment so the Vault Agent sidecar re-injects the new secret:
   `kubectl rollout restart deployment/secureshop -n secureshop`
4. Confirm the application reconnects successfully (check `/actuator/health`).
5. Revoke/expire the old credential at the source (database user, API provider, etc.).
