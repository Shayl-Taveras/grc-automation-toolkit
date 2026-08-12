# Lab 5.4 — GCP Security Services Baseline: Design Spec

## Why

Lab 5.2 stood up AWS's account-level compliance backbone (CloudTrail + Security Hub) as singleton, apply-by-hand services outside the per-resource CI gate. Lab 5.4 mirrors that pattern on GCP: project-scoped singleton controls that can't be expressed as a per-bucket primitive like Lab 2.4's `compliant-gcs-bucket` module, because they govern the project itself, not a resource inside it.

Three controls, one project, applied by hand, evidence captured after:

1. **Org Policy, REJECT enforcement** — three boolean constraints hard-enforced at the API layer, not caught as a post-hoc finding.
2. **Workload Identity Federation for GitHub Actions** — lets `grc-gate.yml` (or a future GCP-side CI gate) authenticate to GCP without a long-lived service account key.
3. **Data Access audit logs** — off by default on GCP, the most commonly cited GCP audit gap. Turned on for the three services this toolkit's GCP resources actually touch.

## Resolved decisions (from prior session)

- **GCP project:** `project-fdec857e-a12f-46d6-b30` — same project as Lab 2.4's `compliant-gcs-bucket` module (`tools/terraform/primitives/compliant-gcs/main.tf`). Confirmed 2026-08-12: reuse it.
- **GitHub repo for WIF binding:** `Shayl-Taveras/grc-automation-toolkit` — confirmed 2026-08-12. The spec's original placeholder (`GRCEngClub/cgep-app-starter`) is discarded.
- **Org scope:** project-scope-only. No assumption made about whether the project sits in a GCP Organization — Org Policy and audit config resources in this design all target `projects/${var.project_id}`, not an org node. If Security Command Center evidence is wanted later, that's a separate follow-up, not part of this lab.

## Controls Enforced

| Control | Family | Mechanism |
|---------|--------|-----------|
| CM-6 | Configuration Settings | Org Policy `storage.uniformBucketLevelAccess` enforced — no bucket in the project can use legacy ACLs |
| AC-2 | Account Management | Org Policy `iam.disableServiceAccountKeyCreation` enforced — no new SA keys can be minted, forces WIF/short-lived credential patterns project-wide |
| AC-3 | Access Enforcement | Org Policy `compute.requireOsLogin` enforced — no static SSH keys on Compute instances |
| IA-2(6) / IA-8 | Identification & Authentication | Workload Identity Federation pool scoped to one GitHub repo via `attribute_condition`, service account has `roles/viewer` only |
| AU-3 / AU-12 | Audit Content / Audit Generation | Data Access audit logs (DATA_READ, DATA_WRITE, ADMIN_READ) turned on for `storage.googleapis.com`, `cloudkms.googleapis.com`, `iam.googleapis.com` |

## Design

### 1. Org Policy (`org_policy.tf`)

Modern `google_org_policy_policy` resource (not the legacy `google_project_organization_policy`), so the constraint value is the string `"TRUE"`, not a `boolean_policy` block:

```hcl
resource "google_org_policy_policy" "uniform_bucket_level_access" {
  name   = "projects/${var.project_id}/policies/storage.uniformBucketLevelAccess"
  parent = "projects/${var.project_id}"

  spec {
    rules {
      enforce = "TRUE"
    }
  }
}
```

Same shape for `iam.disableServiceAccountKeyCreation` and `compute.requireOsLogin` — three resources total, one per constraint, each named after its constraint ID.

**Known interaction:** enforcing `iam.disableServiceAccountKeyCreation` at apply time will block creation of new SA keys project-wide, including any manual `gcloud iam service-accounts keys create` a future lab might reach for. WIF is the intended replacement path — this is the point of the control, not a bug, but worth calling out in the README so a future session doesn't burn time on "why can't I make a key."

### 2. Workload Identity Federation (`workload_identity.tf`)

```hcl
resource "google_iam_workload_identity_pool" "github_actions" {
  workload_identity_pool_id = "github-actions"
  display_name              = "GitHub Actions"
  description               = "WIF pool for grc-automation-toolkit CI"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id         = google_iam_workload_identity_pool.github_actions.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
  }

  # Security-critical: without this, any public GitHub repo could mint a
  # token that impersonates cgep-grc-gate-sa. Scopes the binding to one repo.
  attribute_condition = "assertion.repository == 'Shayl-Taveras/grc-automation-toolkit'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account" "grc_gate" {
  account_id   = "cgep-grc-gate-sa"
  display_name = "GRC gate CI service account (WIF, no keys)"
}

resource "google_project_iam_member" "grc_gate_viewer" {
  project = var.project_id
  role    = "roles/viewer"
  member  = "serviceAccount:${google_service_account.grc_gate.email}"
}

resource "google_service_account_iam_member" "grc_gate_wif_binding" {
  service_account_id = google_service_account.grc_gate.name
  role                = "roles/iam.workloadIdentityUser"
  member              = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_actions.name}/attribute.repository/Shayl-Taveras/grc-automation-toolkit"
}
```

`roles/viewer` is deliberately read-only. This WIF identity is for a future GCP-side evidence-collection gate (read state, don't mutate) — if a later lab needs `terraform apply` from CI, that's a scoped custom role added then, not a broadening of this one.

### 3. Data Access Audit Logs (`audit_logs.tf`)

Same `google_project_iam_audit_config` pattern Lab 05 used for `container.googleapis.com` (see `labs/lab-05-gke-kyverno/main.tf` if that task landed), repeated for three services:

```hcl
resource "google_project_iam_audit_config" "storage" {
  project = var.project_id
  service = "storage.googleapis.com"

  audit_log_config { log_type = "DATA_READ" }
  audit_log_config { log_type = "DATA_WRITE" }
  audit_log_config { log_type = "ADMIN_READ" }
}
```

Repeated for `cloudkms.googleapis.com` and `iam.googleapis.com`. `ADMIN_WRITE` is always on regardless of config and doesn't need a block.

### 4. Tagging / Labeling

No taggable resources exist in this design (Org Policy, WIF, and audit config are all IAM/policy control-plane objects — GCP doesn't support labels on any of them). This deliberately breaks from the label convention in `compliant-gcs-bucket` — there is nothing to attach a label to. Note this in the README so it doesn't read as an oversight.

## File Layout

Mirrors `tools/terraform/baselines/aws/`:

```
tools/terraform/baselines/gcp/
├── main.tf              # terraform block, google provider, project data source
├── variables.tf         # project_id, environment
├── org_policy.tf         # 3x google_org_policy_policy
├── workload_identity.tf  # pool, provider, service account, bindings
├── audit_logs.tf         # 3x google_project_iam_audit_config
├── outputs.tf            # pool name, provider name, SA email — CI wiring inputs
├── README.md              # control coverage table, usage, evidence capture commands
└── evidence/lab-5-4/     # gitignored raw capture; committed sample redacted if needed
```

## Usage (apply-by-hand, same as Lab 5.2)

```bash
gcloud auth application-default login
cd tools/terraform/baselines/gcp
terraform init
terraform plan -var="project_id=project-fdec857e-a12f-46d6-b30"
terraform apply -var="project_id=project-fdec857e-a12f-46d6-b30" -auto-approve
```

## Evidence Capture

```bash
gcloud resource-manager org-policies list --project=project-fdec857e-a12f-46d6-b30 \
  > evidence/lab-5-4/org-policies.json
gcloud iam workload-identity-pools describe github-actions \
  --project=project-fdec857e-a12f-46d6-b30 --location=global --format=json \
  > evidence/lab-5-4/wif-pool.json
gcloud projects get-iam-policy project-fdec857e-a12f-46d6-b30 --format=json \
  > evidence/lab-5-4/iam-audit-config.json
```

Bundle, SHA-256 hash, `cosign sign-blob` (keyless, Sigstore OIDC), upload to the Lab 2.5 evidence vault — same manual pattern as Lab 5.2, since this lab isn't wired into `grc-gate.yml` either.

## Out of Scope

- Wiring the WIF identity into an actual `grc-gate.yml` job — that's a follow-up once a GCP-side evidence check exists to run.
- Security Command Center findings capture — requires an Organization, not confirmed to exist here.
- `terraform destroy` teardown guidance — unlike CloudTrail/Security Hub, none of these three controls bill per-use, so there's no cost-driven urgency to tear down after evidence capture. Leave applied.
