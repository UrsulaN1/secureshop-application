# Production Readiness Checklist (US-061, US-062)

## Security Baseline (US-061)
- [ ] IAM: least-privilege roles for cluster, nodes, and CI (`terraform/modules/eks`)
- [ ] Kubernetes: RBAC (`k8s/rbac`), NetworkPolicies (`k8s/network-policies`), Kyverno (`k8s/kyverno`)
- [ ] Containers: non-root, read-only root FS, no `:latest`, Trivy-clean, Cosign-signed
- [ ] Secrets: all app credentials in Vault, none in Git (verified by `security/ggshield`)
- [ ] CI/CD gates: GitGuardian, SonarQube, OWASP Dependency-Check, Trivy, Checkov all enforced (`ci.yml`, `cd.yml`)
- [ ] Exceptions: any suppression documented in `security/dependency-check-suppressions.xml` or `.checkov.yaml`

## Review (US-062)
- [ ] Application functionality validated end-to-end (browse → cart → order → retrieve)
- [ ] CI/CD pipeline green on `main`
- [ ] Security controls validated (US-057)
- [ ] EKS deployment healthy (`kubectl get pods -n secureshop`)
- [ ] Vault secrets retrieval validated
- [ ] Prometheus/Grafana dashboards populated
- [ ] Loki logs flowing
- [ ] Alertmanager → Slack tested with a synthetic alert
- [ ] Rollback tested (`scripts/rollback.sh`)
- [ ] Outstanding risks documented below

## Outstanding Risks
| Risk | Impact | Mitigation / Owner |
|---|---|---|
| _fill in during review_ | | |
