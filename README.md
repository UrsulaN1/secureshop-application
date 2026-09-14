# SecureShop — Secure Cloud-Native E-Commerce Platform

**A complete DevSecOps + GitOps implementation guide**, built and reviewed by:

- **DevOps Engineer** (source control, Terraform, CI/CD)·
- **Developer** (application, Maven, JUnit)·
- **Security Engineer** (SonarQube, GitGuardian, OWASP, Trivy, Vault)·
- **Cloud/Platform Engineer** (AWS, EKS, Kubernetes, Helm, ArgoCD)·
- **SRE** (Prometheus, Grafana, Alertmanager, logging)·
- **Tech Lead** (final review for accuracy and consistency).

This README contains **only instructions** — every configuration file, manifest, and source file it
references lives in this repository at the path shown. Follow the sections in order; they match the
backlog's **Recommended Epic Implementation Sequence** (Epics 1 → 17).

> **Note on CI/CD tooling:** the source backlog (EPIC 4, US-013–015) specifies **GitHub Actions** as
> the CI/CD engine, so that's what this guide implements end-to-end (`.github/workflows/ci.yml` and
> `cd.yml`). If your organization also standardizes on Jenkins, the same stages (Maven → JUnit →
> SonarQube → Dependency-Check → Docker → Trivy → Syft → Cosign → ECR) map directly onto a
> `Jenkinsfile`

---

## 0. Prerequisites

| Tool | Purpose | Version used in this guide |
| --- | --- | --- |
| Git / GitHub account | Source control | — |
| AWS CLI + an AWS account | Cloud provider | AWS CLI v2 |
| Terraform | Infrastructure as Code | ≥ 1.9 |
| Java 17 + Maven | Application build | Temurin 17 |
| Docker | Container builds | ≥ 24 |
| kubectl | Kubernetes control | matching EKS 1.30 |
| Helm | Package manager for Kubernetes | ≥ 3.14 |
| ArgoCD CLI | GitOps deployments | ≥ 2.11 |
| Vault CLI | Secrets management | ≥ 1.17 |
| Cosign | Image signing | ≥ 2.4 |
| Syft | SBOM generation | ≥ 1.16 |
| Trivy | Container/IaC scanning | ≥ 0.55 |
| Checkov | Terraform scanning | ≥ 3.2 |
| ggshield (GitGuardian) | Secret scanning | ≥ 1.34 |

Install these locally for manual verification; in CI they run automatically inside GitHub Actions.

---

## EPIC 1 — Source Control & Project Foundation
**Owner: DevOps Engineer** · Technology: Git, GitHub, Slack

### US-001 — Create the GitHub repository
1. Create a new **private** GitHub repository named `secureshop`.
2. Copy this entire project structure into it (see the **Repository Layout** section at the bottom
   of this README for the full tree).
3. Confirm the root `.gitignore` (provided) is present — it excludes `target/`, `.terraform/`,
   `*.tfstate`, `*.env`, credential files, and scan-report output, so no secrets or noisy build
   artifacts are ever committed.
4. Commit and push:
   ```bash
   git init
   git add .
   git commit -m "chore: initial SecureShop repository structure"
   git branch -M main
   git remote add origin git@github.com:<your-org>/secureshop.git
   git push -u origin main
   ```

### US-002 — Establish the Git branching strategy
1. In **GitHub → Settings → Branches**, add a branch protection rule for `main`.
2. Branching convention (document this in the repo wiki or `CONTRIBUTING.md`):
   - `main` — protected, always deployable, source of truth for `dev` GitOps sync.
   - `feature/<ticket-id>-<short-description>` — all new work.
   - `release/<version>` — optional, cut before a production promotion.
3. Enable **"Require a pull request before merging"** and **"Do not allow bypassing the above
   settings"** to disable direct pushes to `main`.

### US-003 — Configure GitHub pull-request controls
1. On the same branch protection rule for `main`, enable:
   - **Require a pull request before merging** → **Require approvals: 1** (minimum).
   - **Require status checks to pass before merging** → select the jobs defined in
     `.github/workflows/ci.yml` (`secret-scan`, `build-test-scan`, `terraform-security`,
     `ci-summary`) once they've run at least once (GitHub only lists checks that have executed).
   - **Require branches to be up to date before merging**.
2. This guarantees no code reaches `main` without review and a green CI/security gate.

### US-004 — Integrate Slack notifications
1. In Slack, create an **Incoming Webhook** for a `#secureshop-ci` channel (Slack app directory →
   "Incoming Webhooks").
2. Add the webhook URL as a GitHub Actions secret: **Settings → Secrets and variables → Actions →
   New repository secret** → name it `SLACK_WEBHOOK_URL`.
3. The webhook is already wired into `.github/workflows/cd.yml` (final `Slack notification` step)
   and into Alertmanager (`monitoring/kube-prometheus-stack-values.yaml`) and Falcosidekick
   (`falco/falco-values.yaml`) for pipeline, deployment, and security-alert notifications. No
   secret values or credentials are ever included in the message payloads.

---

## EPIC 2 — AWS Foundation & Infrastructure as Code
**Owner: DevOps Engineer** · Technology: AWS, Terraform, Checkov

### US-005 — AWS architecture design
The architecture implemented by the Terraform in this repo:
- **VPC** (`10.20.0.0/16`) spanning 3 AZs, with public subnets (NAT/ALB) and private subnets
  (EKS nodes, no direct internet ingress).
- **EKS** cluster in the private subnets, control-plane logging enabled, secrets encrypted with a
  dedicated KMS key, OIDC provider enabled for IRSA.
- **ECR** private, immutable-tag repository with scan-on-push.
- **IAM** separated into a cluster role, a node role, and (via OIDC/IRSA) fine-grained workload
  roles — no shared "god" role.
- Application ↔ database communication stays inside private subnets/security groups; only the
  ALB/ingress path is public.

📄 Diagram source of truth: keep an updated architecture diagram in `docs/architecture.drawio` (add
your export as `docs/architecture.png`) reflecting the modules under `terraform/modules/`.

### US-006 — Create the Terraform project structure
Structure (already in this repo):
```
terraform/
  versions.tf        # provider version pins
  providers.tf        # AWS provider + default tags
  backend.tf           # US-008 remote state config
  variables.tf         # externalized inputs
  main.tf               # composes the vpc/ecr/eks modules
  outputs.tf
  modules/
    vpc/    (main.tf, variables.tf, outputs.tf)
    ecr/    (main.tf, variables.tf, outputs.tf)
    eks/    (main.tf, variables.tf, outputs.tf)
  environments/dev/terraform.tfvars.example
```
Verify formatting and initialization:
```bash
cd terraform
terraform fmt -recursive
terraform init -backend=false   # validate-only, no backend yet
terraform validate
```

### US-007 — Provision AWS networking with Terraform
Implemented in `terraform/modules/vpc/main.tf`: VPC, IGW, 3 public + 3 private subnets, one NAT
gateway per AZ, route tables, and a default restrictive security group. Provisioned automatically
when you run `terraform apply` in the next step (after configuring remote state).

### US-008 — Configure Terraform remote state
1. One-time bootstrap of the S3 bucket + DynamoDB lock table:
   ```bash
   ./scripts/bootstrap-backend.sh
   ```
2. Update `terraform/backend.tf` with the bucket name it prints.
3. Initialize against the real backend:
   ```bash
   cd terraform
   terraform init -migrate-state
   ```
   State is now versioned, encrypted, access-restricted, and lock-protected — and is excluded from
   Git by `.gitignore`.

### US-009 — Scan Terraform with Checkov
Config: `security/checkov/.checkov.yaml`. Run locally:
```bash
checkov -d terraform --config-file security/checkov/.checkov.yaml
```
This same command runs automatically in `.github/workflows/ci.yml` (`terraform-security` job).
High/critical findings fail the pipeline; any accepted false positive must be added to
`skip-check` in `.checkov.yaml` with a comment explaining why (documented exception).

Provision the infrastructure once the scan is clean:
```bash
terraform plan  -var-file=environments/dev/terraform.tfvars.example
terraform apply -var-file=environments/dev/terraform.tfvars.example
```

---

## EPIC 3 — Application Foundation & Automated Testing
**Owner: Developer** · Technology: Maven, JUnit

### US-010 — Create the SecureShop application
Source: `app/src/main/java/com/secureshop/`
- `SecureShopApplication.java` — Spring Boot entry point.
- `model/Product.java`, `model/Order.java`, `model/OrderItem.java` — domain model.
- `service/ProductService.java` — product catalog / browse logic.
- `service/OrderService.java` — order submission, stock reservation, total calculation.
- `controller/ProductController.java` — `GET /api/v1/products`, `GET /api/v1/products/{id}`.
- `controller/OrderController.java` — `POST /api/v1/orders`, `GET /api/v1/orders/{id}`,
  `GET /api/v1/orders`.
- `config/GlobalExceptionHandler.java` — consistent error responses.
- `application.yml` — all configuration externalized via environment variables; DB credentials are
  deliberately left blank here and are injected at runtime by Vault (see EPIC 10).

Run locally:
```bash
cd app
mvn spring-boot:run
curl http://localhost:8080/api/v1/products
```

### US-011 — Configure the Maven build
`app/pom.xml` defines the Spring Boot parent, dependencies, and plugins (Spring Boot Maven plugin,
JaCoCo for coverage, OWASP Dependency-Check — see EPIC 5). Build non-interactively:
```bash
mvn -B -ntp clean package
```
A non-zero exit code on failure is Maven's default behavior — no extra configuration needed for
that acceptance criterion.

### US-012 — Implement JUnit unit tests
`app/src/test/java/com/secureshop/service/ProductServiceTest.java` and `OrderServiceTest.java`
cover the critical business logic (stock reservation, order total calculation, error paths).
```bash
mvn -B -ntp test
```
Minimum coverage expectation for this project: **≥ 70% line coverage on `service/` classes**,
enforced via the SonarQube quality gate (EPIC 5) reading the JaCoCo report
(`target/site/jacoco/jacoco.xml`).

---

## EPIC 4 — CI Pipeline with GitHub Actions
**Owner: DevOps Engineer** · Technology: GitHub Actions

### US-013 / US-014 — CI workflow for pull requests and `main`
Workflow file: `.github/workflows/ci.yml`. Triggers on every pull request into `main` and every
push to `main`. Stages, in order:
1. `secret-scan` — GitGuardian (EPIC 5)
2. `build-test-scan` — Maven build → JUnit tests → OWASP Dependency-Check → SonarQube (EPIC 3, 5)
3. `terraform-security` — `terraform fmt`/`validate` → Checkov (EPIC 2)
4. `ci-summary` — gate that only goes green once all of the above pass

Required GitHub Actions secrets to configure (**Settings → Secrets and variables → Actions**):
`GITGUARDIAN_API_KEY`, `SONAR_TOKEN`, `SONAR_HOST_URL`, `SLACK_WEBHOOK_URL`.

A failed stage in any job stops that job and prevents the `ci-summary` gate — and therefore the
branch-protection required check — from passing, which blocks the PR merge.

### US-015 — Artifact handling
`build-test-scan` uploads `build-artifacts` (jar + Surefire test reports) and
`dependency-check-report` with 14–30 day retention via `actions/upload-artifact@v4`, so failed runs
can be investigated from the GitHub Actions UI without re-running the build.

---

## EPIC 5 — Application Security & Secure Coding
**Owner: Security Engineer** · Technology: GitGuardian/ggShield, SonarQube, OWASP Dependency-Check

### US-016 — GitGuardian secret scanning
Config: `security/ggshield/.gitguardian.yaml`. Runs as the very first CI job (`secret-scan` in
`ci.yml`) so nothing downstream even builds if a secret is detected. Locally:
```bash
ggshield secret scan repo .
```
If a secret is ever detected in history: rotate it immediately at the source, then purge it from
Git history (`git filter-repo` or BFG), then force-push and have all collaborators re-clone.

### US-017 — Integrate SonarQube
Runs in the `build-test-scan` job of `ci.yml` via `mvn sonar:sonar`, reading JaCoCo coverage
(`app/pom.xml` JaCoCo plugin). Set up once:
1. Stand up SonarQube (SonarCloud or self-hosted) and create a project with key `secureshop`.
2. Generate a token, store it as the `SONAR_TOKEN` GitHub secret; store the server URL as
   `SONAR_HOST_URL`.
3. `sonar.qualitygate.wait=true` (set in `ci.yml`) makes the pipeline block until the quality gate
   result is known, and fail the build if the gate fails.

### US-018 — Configure OWASP Dependency-Check
Configured in `app/pom.xml` (the `dependency-check-maven` plugin) with
`failBuildOnCVSS=7` and suppressions read from `security/dependency-check-suppressions.xml`. Any
suppression must include an approver name, date, and reason (template provided in that file) per
the Definition of Done.

### US-019 — Application security gates
`ci.yml`'s `ci-summary` job is the single required status check that only passes once secret
scanning, SonarQube's quality gate, and Dependency-Check have all succeeded — this is the
enforcement point for this story. Document any approved exception (a suppressed CVE, a Checkov
skip-check) directly in the relevant config file, as shown above.

---

## EPIC 6 — Containerization & Container Security
**Owner: Security Engineer / DevOps Engineer** · Technology: Docker, Trivy, Syft, Cosign

### US-020 — Create the production Dockerfile
`app/Dockerfile` — multi-stage build: `eclipse-temurin:17-jdk-jammy` to compile, then a slim
`eclipse-temurin:17-jre-jammy` runtime image (no build tools shipped in the final image).

### US-021 — Secure Docker image practices
Same Dockerfile: dedicated non-root user (`uid 1001`), no unnecessary packages in the runtime
stage, `app/.dockerignore` excludes `target/`, `.git/`, IDE files, and Markdown docs from the build
context, and a `HEALTHCHECK` is defined. Build and confirm:
```bash
cd app
docker build -t secureshop:local .
docker run -p 8080:8080 secureshop:local
docker inspect secureshop:local --format '{{.Config.User}}'   # should print "1001"
```

### US-022 — Integrate Trivy container scanning
Runs in `.github/workflows/cd.yml` (`Trivy vulnerability scan` step) against every image before
it's pushed to ECR, failing the job on CRITICAL/HIGH findings. Run locally:
```bash
trivy image secureshop:local --severity CRITICAL,HIGH
```

### US-023 — Generate an SBOM with Syft
Also in `cd.yml` (`Generate SBOM (Syft)` step), producing a CycloneDX JSON SBOM per image, uploaded
as a build artifact and later attached to the image as a Cosign attestation (next story). Locally:
```bash
syft secureshop:local -o cyclonedx-json > secureshop-sbom.cdx.json
```

### US-024 — Sign container images with Cosign
`cd.yml` uses **keyless signing** (Sigstore/Fulcio via GitHub Actions OIDC — no long-lived signing
key to manage or leak) after Trivy has passed, and attests the SBOM to the image. Verify a signed
image:
```bash
cosign verify \
  --certificate-identity-regexp "https://github.com/secureshop-org/secureshop/.github/workflows/cd.yml@.*" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  <ecr-repo-url>/secureshop:<tag>
```

---

## EPIC 7 — AWS ECR Container Registry
**Owner: Cloud/Platform Engineer** · Technology: AWS ECR

### US-025 — Create the ECR repository
Provisioned by Terraform: `terraform/modules/ecr/main.tf` — immutable tags, scan-on-push, KMS
encryption, and a repository policy restricted to the current AWS account. Already wired into
`terraform/main.tf`; created as part of the `terraform apply` in EPIC 2.

### US-026 — Push validated images to ECR
Handled end-to-end by `.github/workflows/cd.yml`: build → Trivy scan → Syft SBOM → Cosign sign →
**then** `docker push`. If any security step fails, the job stops before the push step ever runs —
enforced by GitHub Actions' default fail-fast step ordering.

### US-027 — Immutable image tagging strategy
- ECR repository has `image_tag_mutability = "IMMUTABLE"` (`terraform/modules/ecr/main.tf`).
- `cd.yml` tags every image with `${{ github.sha }}` — the Git commit SHA — giving exact
  image-to-source traceability.
- `k8s/kyverno/disallow-latest-tag.yaml` enforces at admission time that no pod in the `secureshop`
  namespace may run an image tagged `:latest`.

---

## EPIC 8 — Amazon EKS Platform
**Owner: Cloud/Platform Engineer** · Technology: AWS, Amazon EKS

### US-028 — Provision the EKS cluster
`terraform/modules/eks/main.tf` provisions the cluster (control-plane logging on for all log
types, KMS-encrypted secrets, a managed node group in private subnets), created by the same
`terraform apply` as EPIC 2. Confirm access:
```bash
aws eks update-kubeconfig --name secureshop-dev --region us-east-1
kubectl get nodes
```

### US-029 — Configure EKS IAM integration
- The **OIDC provider** (`aws_iam_openid_connect_provider.eks`) enables IRSA so individual
  Kubernetes workloads/controllers assume narrowly-scoped IAM roles instead of node-wide
  permissions.
- Human/administrative access should be granted via **EKS access entries** mapped to IAM
  users/roles/SSO groups — not via a shared cluster-admin kubeconfig. Map your `secureshop-developers`
  IAM/SSO group to the Kubernetes group referenced in `k8s/rbac/rolebindings.yaml`.
- Workload permissions (node IAM role) are intentionally separate from both the cluster role and
  any human-access roles.

### US-030 — Deploy a test workload
```bash
kubectl create namespace smoke-test
kubectl run nginx-test --image=nginx --namespace=smoke-test
kubectl wait --for=condition=Ready pod/nginx-test -n smoke-test --timeout=60s
kubectl expose pod nginx-test --port=80 --namespace=smoke-test
kubectl logs nginx-test -n smoke-test
kubectl delete namespace smoke-test
```

---

## EPIC 9 — Kubernetes Security & Policy Enforcement
**Owner: Security Engineer / Cloud/Platform Engineer** · Technology: RBAC, Network Policies, Kyverno

### US-031 — Implement Kubernetes RBAC
Manifests: `k8s/rbac/namespace.yaml`, `roles.yaml`, `rolebindings.yaml`. Apply:
```bash
kubectl apply -f k8s/rbac/namespace.yaml
kubectl apply -f k8s/rbac/roles.yaml
kubectl apply -f k8s/rbac/rolebindings.yaml
```
`secureshop-app-role` gives the application's own ServiceAccount only `configmaps` read access —
no write access to any cluster resource. `secureshop-developer-role` gives read-only visibility
into pods/services/deployments for the mapped developer group.

### US-032 — Implement Kubernetes Network Policies
Manifests: `k8s/network-policies/default-deny.yaml` (deny everything by default) and
`allow-app-traffic.yaml` (explicitly allow: ingress from the ingress-controller namespace on
port 8080; egress to DNS, to the `vault` namespace on 8200, and to the database CIDR on 5432).
```bash
kubectl apply -f k8s/network-policies/
```

### US-033 — Implement Kyverno policies
```bash
helm repo add kyverno https://kyverno.github.io/kyverno/
helm install kyverno kyverno/kyverno -n kyverno --create-namespace
kubectl apply -f k8s/kyverno/
```
Policies applied (all `validationFailureAction: Enforce`, so non-compliant workloads are
**rejected**, not just reported):
- `require-non-root.yaml`
- `disallow-privileged.yaml`
- `require-resource-limits.yaml`
- `require-image-signature.yaml` — rejects any `secureshop` image not signed by the `cd.yml`
  workflow identity (closes the loop with EPIC 6's Cosign signing).
- `disallow-latest-tag.yaml`

### US-034 — Enforce secure workload configuration
Enforced by the combination of the Helm chart's pod `securityContext`
(`helm/secureshop/values.yaml`: `runAsNonRoot`, `readOnlyRootFilesystem`, dropped Linux
capabilities, defined resource requests/limits) and the Kyverno policies above that validate it at
admission time.

---

## EPIC 10 — Secrets Management with HashiCorp Vault
**Owner: Security Engineer** · Technology: HashiCorp Vault

### US-035 — Deploy HashiCorp Vault
```bash
helm repo add hashicorp https://helm.releases.hashicorp.com
helm install vault hashicorp/vault -n vault --create-namespace -f vault/vault-values.yaml
kubectl -n vault exec -it vault-0 -- vault operator init   # first-time only; store keys securely
```
`vault/vault-values.yaml` runs Vault in HA/Raft mode (3 replicas), enables the Agent Injector, and
hardens the pod (`runAsNonRoot`, no privilege escalation).

### US-036 — Store application secrets in Vault
```bash
export VAULT_ADDR=http://127.0.0.1:8200   # after `kubectl port-forward svc/vault -n vault 8200:8200`
vault kv put secret/secureshop/dev/db username="secureshop_app" password="$(openssl rand -base64 24)"
```
Script provided: `vault/secureshop-secrets-example.sh`. The least-privilege read-only policy for
the app is `vault/secureshop-app-policy.hcl` — no write/delete access is granted to the workload
identity. Secret rotation is documented in `docs/runbooks.md` (§6).

### US-037 — Integrate Kubernetes workloads with Vault
```bash
./vault/k8s-auth-setup.sh
```
This enables the Kubernetes auth method, writes the `secureshop-app` policy, and creates a role
bound to the `secureshop` ServiceAccount in the `secureshop` namespace. The Helm chart
(`helm/secureshop/templates/deployment.yaml`) already carries the `vault.hashicorp.com/agent-inject`
annotations, so once this is configured, every new pod automatically receives its DB credentials
as a file injected by the Vault Agent sidecar — never as a plain Kubernetes Secret or environment
variable baked into the image.

---

## EPIC 11 — Helm Application Packaging
**Owner: Cloud/Platform Engineer** · Technology: Helm

### US-038 — Create the SecureShop Helm chart
`helm/secureshop/`: `Chart.yaml`, `values.yaml`, `templates/deployment.yaml`, `service.yaml`,
`serviceaccount.yaml`, `hpa.yaml`, `_helpers.tpl`. Validate:
```bash
helm lint helm/secureshop
helm template helm/secureshop -f helm/secureshop/values-dev.yaml
```

### US-039 — Environment-specific Helm values
`values-dev.yaml`, `values-staging.yaml`, `values-prod.yaml` override replica counts, autoscaling
bounds, resource sizing, and the Vault secret path per environment. No plaintext secrets appear in
any of these files — only the Vault path to fetch them from.

---

## EPIC 12 — GitOps with ArgoCD
**Owner: Cloud/Platform Engineer** · Technology: ArgoCD

### US-040 — Create the GitOps repository
Create a **second** repository, `secureshop-gitops`, containing a copy of `helm/secureshop/` plus
an `environments/<env>/values.yaml` overlay per environment. Protect its `main` branch with
required PR review, exactly as in US-003 — this is the audit trail for every production change.
`.github/workflows/cd.yml` commits new image tags into this repo automatically (see US-056 below).

### US-041 — Deploy ArgoCD
```bash
./scripts/bootstrap-argocd.sh
```
Installs ArgoCD into the `argocd` namespace on EKS and registers the three Application manifests
in `gitops/apps/` (`secureshop-dev.yaml`, `secureshop-staging.yaml`, `secureshop-prod.yaml`).

### US-042 — Automated GitOps deployment
Each `Application` in `gitops/apps/` sets `syncPolicy.automated: {prune: true, selfHeal: true}`
(prod uses `prune: false` as an extra manual-confirmation gate) — ArgoCD watches the GitOps repo
and reconciles the cluster to match it automatically, with no manual `kubectl apply` in the loop.
Watch it work: `argocd app get secureshop-dev` or the ArgoCD UI.

### US-043 — Deployment rollback
```bash
./scripts/rollback.sh dev
```
Walks through `argocd app history`, prompts for the target revision, rolls back, and waits for
health. Full procedure documented in `docs/runbooks.md` (§3).

---

## EPIC 13 — Runtime Security with Falco
**Owner: Security Engineer** · Technology: Falco

### US-044 — Deploy Falco to EKS
```bash
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm install falco falcosecurity/falco -n falco --create-namespace -f falco/falco-values.yaml
kubectl -n falco get pods
```
Falcosidekick is enabled and wired to the same Slack webhook from US-004.

### US-045 — Configure runtime security rules
`falco/custom-rules.yaml` adds two SecureShop-specific rules on top of Falco's stock rule set:
detecting an interactive shell spawned inside the app container, and unexpected outbound
connections from it. Apply via the Helm `customRules` value (already referenced in
`falco-values.yaml`'s `rules_file` list) or `helm upgrade -f falco/custom-rules.yaml`. Trigger a
test event and confirm it reaches Slack:
```bash
kubectl exec -it deploy/secureshop -n secureshop -- sh -c "echo test"
```

---

## EPIC 14 — Monitoring, Logging & Observability
**Owner: SRE** · Technology: Prometheus, Grafana, Alertmanager, CloudWatch, Loki

### US-046 — Deploy Prometheus
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace -f monitoring/kube-prometheus-stack-values.yaml
```
This single chart also deploys Grafana and Alertmanager (next two stories).

### US-047 — Create Grafana dashboards
Import `monitoring/grafana-dashboard-secureshop.json` (Grafana UI → Dashboards → Import, or drop it
into a ConfigMap labeled `grafana_dashboard: "1"` for the sidecar to auto-load, per
`kube-prometheus-stack-values.yaml`). Panels: request rate, 5xx error rate, pod CPU, pod memory,
pod health table, and live logs (via the Loki data source configured in the same values file).

### US-048 — Configure Alertmanager
Alert routing/receivers are defined inline in `monitoring/kube-prometheus-stack-values.yaml`
(`alertmanager.config`). Alert rules: `monitoring/secureshop-alert-rules.yaml` — apply with:
```bash
kubectl apply -f monitoring/secureshop-alert-rules.yaml -n monitoring
```
Covers: high 5xx error rate, pod crash-looping, high memory usage — each with a defined `for`
duration to avoid flapping, and severity labels used for routing.

### US-049 — Integrate Prometheus alerts with Slack
Same `alertmanager.config` block routes everything to the `slack-notifications` receiver, posting
to `#secureshop-alerts` using the `SLACK_WEBHOOK_URL` secret (stored as a Kubernetes Secret, never
committed — reference it with `--set-file` or a sealed-secret at install time). Test:
```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-alertmanager 9093
# trigger a test alert via the Alertmanager UI's "Silence"/"New alert" test tooling
```

### US-050 — Deploy Loki for centralized logging
```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm install loki grafana/loki -n monitoring -f monitoring/loki-values.yaml
```
14-day retention configured in `loki-values.yaml`; Promtail ships every pod's logs automatically.

### US-051 — Integrate Loki with Grafana
Already configured as an `additionalDataSources` entry in
`monitoring/kube-prometheus-stack-values.yaml`, so Grafana can query logs (`{namespace="secureshop"}`)
right next to the metrics panels in the same dashboard.

### US-052 — Configure AWS CloudWatch monitoring
`monitoring/cloudwatch-alarms.tf` — copy into `terraform/` (e.g. as `terraform/monitoring.tf`) and
`terraform apply`. Creates a CloudWatch log group for the EKS control plane and alarms for node CPU
and ECR high-severity scan findings. For full node/pod-level CloudWatch metrics, also install the
**CloudWatch Container Insights** add-on via `eksctl` or the AWS console.

---

## EPIC 15 — End-to-End DevSecOps Pipeline Integration
**Owner: DevOps Engineer / Security Engineer** · Technology: entire stack

### US-053, US-054, US-055 — Integrated CI/CD security pipeline
No new files here — these stories are the **integration** of everything above, already wired
together across `.github/workflows/ci.yml` and `cd.yml`:
- **Application security** (US-053): GitGuardian → Maven → JUnit → SonarQube → Dependency-Check,
  all in `ci.yml`.
- **Container supply chain** (US-054): Docker build → Trivy → Syft → Cosign → ECR push, all in
  `cd.yml`.
- **Infrastructure security** (US-055): `terraform fmt`/`validate` → Checkov, in `ci.yml`'s
  `terraform-security` job.

### US-056 — End-to-end GitOps release
Full flow, already implemented across the two workflow files:
```
git push → GitHub Actions CI (build/test/security gates)
          → GitHub Actions CD (build image → Trivy → Syft SBOM → Cosign sign → push to ECR)
          → CD updates image tag in the secureshop-gitops repo
          → ArgoCD detects the Git change and syncs EKS
          → Application becomes healthy
```
Verify the whole chain with one commit:
```bash
git commit --allow-empty -m "test: verify end-to-end pipeline"
git push origin main
# watch: GitHub Actions tab -> then `argocd app get secureshop-dev` -> then `kubectl get pods -n secureshop`
```

---

## EPIC 16 — Security, Reliability & Operational Validation
**Owner: Security Engineer / SRE / Tech Lead** · Technology: OWASP ZAP + entire stack

### US-057 — End-to-end security validation
Run through this checklist against a live dev/staging environment and record results in
`docs/production-readiness-checklist.md`:
- Commit a dummy secret on a branch → confirm `secret-scan` blocks the PR.
- Add a known-vulnerable dependency version to `pom.xml` on a branch → confirm Dependency-Check
  fails the build.
- Build an image with an intentionally outdated base image → confirm Trivy fails `cd.yml`.
- Introduce a Terraform misconfiguration (e.g. an open security group) → confirm Checkov fails CI.
- `kubectl auth can-i create pods --as=system:serviceaccount:secureshop:secureshop -n secureshop`
  → should be `no` (RBAC, US-031).
- Attempt cross-namespace traffic to the app pod from a non-allowed namespace → should be dropped
  (NetworkPolicy, US-032).
- Deploy a manifest without resource limits or with a privileged container → Kyverno should reject
  it (US-033/034).
- `kubectl exec` a shell into the app pod → confirm a Falco alert reaches Slack (US-044/045).

### US-058 — OWASP ZAP dynamic application security testing
Workflow: `.github/workflows/dast.yml`, rule overrides in `security/zap/zap-baseline.conf`. Runs
nightly against staging and on-demand via `workflow_dispatch`. Critical/high findings (per the
rules file thresholds) fail the workflow; any accepted finding must be added to
`zap-baseline.conf` with a comment.

### US-059 — Disaster/recovery validation
1. **Failed deployment recovery**: push a deliberately broken image tag to the GitOps repo dev
   overlay, confirm ArgoCD reports `Degraded`, then run `scripts/rollback.sh dev`.
2. **Infrastructure recreation**: in a scratch AWS account/region, run
   `terraform destroy && terraform apply` against `terraform/environments/dev` end-to-end and time
   it — this is your recovery-time baseline.
3. **Vault backups**: confirm Raft snapshots are being taken (`vault operator raft snapshot save`)
   and test a restore in a non-production Vault instance.
4. Record results in `docs/runbooks.md`.

### US-060 — Operational runbooks
All six required runbooks are in `docs/runbooks.md`: pipeline failure, Kubernetes failure,
application rollback, security incident, monitoring/alert troubleshooting, and secrets rotation.

---

## EPIC 17 — Final Production Readiness
**Owner: Tech Lead** · Technology: entire platform

### US-061 — Production security baseline
Documented in `docs/production-readiness-checklist.md` §"Security Baseline" — IAM, Kubernetes,
container, secrets-management, and CI/CD gate requirements, each with a pointer back to the
enforcing file in this repo.

### US-062 — Production readiness review
**Tech Lead** walks the full checklist in `docs/production-readiness-checklist.md` before any
`prod` promotion: functionality, CI/CD, security controls, EKS, secrets, monitoring, logging,
alerting, and rollback — signing off against each item and logging any outstanding risk in the
table at the bottom of that document.

### US-063 — Complete DevSecOps architecture documentation
This README **is** that documentation for process/how-to; pair it with:
- `docs/architecture.png` (diagram, US-005)
- `docs/runbooks.md` (troubleshooting, US-060)
- `docs/production-readiness-checklist.md` (validation, US-061/062)
- Inline comments in every Terraform, Helm, Kubernetes, and workflow file referencing the user
  story it satisfies, so the mapping from code back to backlog is always traceable.

---

## Final DevSecOps Flow (for reference)

```
GitHub → Pull Request → GitHub Actions CI
   → GitGuardian → Maven → JUnit → SonarQube → OWASP Dependency-Check
   → Terraform fmt/validate + Checkov
→ merge to main → GitHub Actions CD
   → Docker Build → Trivy → Syft (SBOM) → Cosign (sign) → AWS ECR
→ GitOps repository updated
   → ArgoCD sync → Amazon EKS
   → RBAC + Network Policies + Kyverno enforce at admission
   → HashiCorp Vault injects secrets at runtime
   → Falco watches runtime behavior
→ Prometheus + Loki + CloudWatch collect metrics/logs
   → Grafana + Alertmanager visualize and alert
   → Slack notifies the team
```

---

## Repository Layout

```
secureshop/
├── README.md                         # this file
├── .gitignore
├── app/                               # EPIC 3, 6 — Developer
│   ├── pom.xml
│   ├── Dockerfile
│   ├── .dockerignore
│   └── src/main/java/com/secureshop/...
├── .github/workflows/                 # EPIC 4, 5, 6, 15, 16 — DevOps/Security
│   ├── ci.yml
│   ├── cd.yml
│   └── dast.yml
├── terraform/                         # EPIC 2, 8 — DevOps/Cloud
│   ├── main.tf / variables.tf / outputs.tf / backend.tf / providers.tf / versions.tf
│   ├── modules/{vpc,ecr,eks}/
│   └── environments/dev/terraform.tfvars.example
├── security/                          # EPIC 2, 5, 6, 16 — Security Engineer
│   ├── checkov/.checkov.yaml
│   ├── ggshield/.gitguardian.yaml
│   ├── dependency-check-suppressions.xml
│   └── zap/zap-baseline.conf
├── k8s/                                # EPIC 9 — Security/Cloud
│   ├── rbac/
│   ├── network-policies/
│   └── kyverno/
├── vault/                              # EPIC 10 — Security Engineer
├── helm/secureshop/                    # EPIC 11 — Cloud/Platform Engineer
├── gitops/apps/                        # EPIC 12 — Cloud/Platform Engineer
├── falco/                              # EPIC 13 — Security Engineer
├── monitoring/                         # EPIC 14 — SRE
├── scripts/                            # bootstrap + operational helpers
└── docs/                               # EPIC 16, 17 — runbooks, checklists
```

---

## Sign-off (Tech Lead review — US-062, US-063)

This document and the referenced configuration were reviewed for:
- **Accuracy**: every instruction maps to a real file in this repository at the stated path.
- **Consistency**: naming (`secureshop`), tagging (commit-SHA), and namespace (`secureshop`)
  conventions are used identically across Terraform, Helm, Kubernetes, and CI/CD.
- **Sequencing**: sections follow the backlog's Recommended Epic Implementation Sequence exactly,
  so a new engineer can execute this README top-to-bottom on a fresh AWS account.

Outstanding items before a real production launch: fill in `docs/architecture.png`, replace all
`<ACCOUNT_ID>` / `<your-org>` placeholders, and complete the risk table in
`docs/production-readiness-checklist.md`.
