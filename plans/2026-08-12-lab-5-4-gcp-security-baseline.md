# Lab 5.4: GCP Security Services Baseline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **User authoring convention:** This is a capstone lab. The user pastes all `.tf` and `README.md` content themselves. The assistant supplies the exact snippet inline at each step and gives exact CLI commands to run — it does not write infrastructure files directly. See `feedback_coding_style` memory.

**Goal:** Stand up three project-scoped GCP singleton controls — Org Policy REJECT enforcement, Workload Identity Federation for GitHub Actions, and Data Access audit logging — mirroring Lab 5.2's AWS account-baseline pattern (apply by hand, not CI-gated, evidence captured after apply).

**Architecture:** Single baseline folder at `tools/terraform/baselines/gcp/`. Local state, no Makefile (Lab 5.2's AWS baseline doesn't use one either — plain `terraform` commands). No teardown step: unlike CloudTrail/Security Hub, none of these three controls bill per-use.

**Tech Stack:** Terraform >= 1.6, `hashicorp/google` provider ~> 5.0, gcloud SDK, jq, cosign.

**Spec reference:** `specs/2026-08-12-lab-5-4-gcp-security-baseline-design.md`

**Verification model:** Same compliance-as-test pattern as Lab 05 — each task that adds a resource ends with `terraform validate` plus `terraform plan -out=tfplan` followed by a `jq` assertion that the expected resource/attribute appears in the planned state.

## Global Constraints

- GCP project ID: `project-fdec857e-a12f-46d6-b30` (reused from Lab 2.4 — confirmed 2026-08-12, do not re-ask).
- GitHub repo for WIF `attribute_condition`: `Shayl-Taveras/grc-automation-toolkit` (confirmed 2026-08-12, discard the spec's original placeholder repo).
- Labels/tags: none of these resources are taggable in GCP (IAM/policy control-plane objects). Do not attempt to add a `labels` block anywhere in this lab — there is nothing to attach one to.
- File layout mirrors `tools/terraform/baselines/aws/` exactly: `main.tf`, `variables.tf`, one `.tf` per control area, `outputs.tf`, `README.md`, `evidence/lab-5-4/`.

**Prerequisites before starting:**

- `gcloud auth application-default login` completed against `project-fdec857e-a12f-46d6-b30`.
- `terraform`, `gcloud`, `jq`, `cosign` on PATH.
- Export the project ID once at the start of Task 1 and leave it set: `export TF_VAR_project_id=project-fdec857e-a12f-46d6-b30`.

---

## Task 1: Bootstrap the baseline directory

**Files:**
- Create: `tools/terraform/baselines/gcp/main.tf`
- Create: `tools/terraform/baselines/gcp/.gitignore`

- [ ] **Step 1: Create the directory and set the project variable**

Run from repo root:

```bash
mkdir -p tools/terraform/baselines/gcp/evidence/lab-5-4
cd tools/terraform/baselines/gcp
export TF_VAR_project_id=project-fdec857e-a12f-46d6-b30
```

Stay in this directory for the rest of the plan.

- [ ] **Step 2: Paste this snippet into `main.tf`**

```hcl
# main.tf
terraform {
  required_version = ">= 1.6"
  required_providers {
    google = { source = "hashicorp/google", version = "~> 5.0" }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_project" "current" {
  project_id = var.project_id
}
```

- [ ] **Step 3: Paste this snippet into `.gitignore`**

```
.terraform/
terraform.tfstate
terraform.tfstate.*
*.tfstate.backup
tfplan
evidence/lab-5-4/*.json
!evidence/lab-5-4/.gitkeep
```

- [ ] **Step 4: Add the evidence directory keep-file**

```bash
touch evidence/lab-5-4/.gitkeep
```

- [ ] **Step 5: Initialise**

Run:

```bash
terraform init
```

Expected: `Terraform has been successfully initialized!` and a `.terraform/` directory appears.

- [ ] **Step 6: Commit**

```bash
git add tools/terraform/baselines/gcp/main.tf \
        tools/terraform/baselines/gcp/.gitignore \
        tools/terraform/baselines/gcp/evidence/lab-5-4/.gitkeep
git commit -m "feat(lab-5-4): scaffold gcp security baseline"
```

---

## Task 2: Define input variables

**Files:**
- Create: `tools/terraform/baselines/gcp/variables.tf`

- [ ] **Step 1: Paste this snippet into `variables.tf`**

```hcl
# variables.tf
variable "project_id" {
  description = "GCP project ID for Lab 5.4 (reused from Lab 2.4). String ID, not the numeric project number."
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be a valid GCP project ID string (lowercase alphanumerics and hyphens)."
  }
}

variable "region" {
  description = "GCP region for the provider default. No regional resources in this baseline, kept for provider config only."
  type        = string
  default     = "us-central1"
}

variable "github_repo" {
  description = "GitHub repo allowed to impersonate the WIF service account, as owner/name."
  type        = string
  default     = "Shayl-Taveras/grc-automation-toolkit"
}
```

- [ ] **Step 2: Validate**

```bash
terraform validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 3: Commit**

```bash
git add tools/terraform/baselines/gcp/variables.tf
git commit -m "feat(lab-5-4): add gcp baseline variables"
```

---

## Task 3: Org Policy — REJECT enforcement

**Files:**
- Create: `tools/terraform/baselines/gcp/org_policy.tf`

**Interfaces:**
- Consumes: `var.project_id` from Task 2.
- Produces: `google_org_policy_policy.uniform_bucket_level_access`, `google_org_policy_policy.disable_sa_key_creation`, `google_org_policy_policy.require_os_login` — referenced by no later task, evidence-only.

- [ ] **Step 1: Paste this snippet into `org_policy.tf`**

```hcl
# org_policy.tf
# Control Coverage: CM-6, AC-2, AC-3
# Framework: NIST 800-53 Rev 5 | FedRAMP Moderate

# CM-6: no bucket in the project may use legacy ACLs.
resource "google_org_policy_policy" "uniform_bucket_level_access" {
  name   = "projects/${var.project_id}/policies/storage.uniformBucketLevelAccess"
  parent = "projects/${var.project_id}"

  spec {
    rules {
      enforce = "TRUE"
    }
  }
}

# AC-2: no new service account keys can be minted project-wide.
# This forces WIF / short-lived credentials for anything created after apply,
# including future manual `gcloud iam service-accounts keys create` calls.
resource "google_org_policy_policy" "disable_sa_key_creation" {
  name   = "projects/${var.project_id}/policies/iam.disableServiceAccountKeyCreation"
  parent = "projects/${var.project_id}"

  spec {
    rules {
      enforce = "TRUE"
    }
  }
}

# AC-3: no static SSH keys on Compute instances project-wide.
resource "google_org_policy_policy" "require_os_login" {
  name   = "projects/${var.project_id}/policies/compute.requireOsLogin"
  parent = "projects/${var.project_id}"

  spec {
    rules {
      enforce = "TRUE"
    }
  }
}
```

- [ ] **Step 2: Validate and plan**

```bash
terraform validate
terraform plan -out=tfplan
```

Expected: plan shows 3 resources to add, no errors.

- [ ] **Step 3: Assert the three constraints are present with `enforce = TRUE`**

```bash
terraform show -json tfplan | jq '
  [.resource_changes[]
    | select(.type == "google_org_policy_policy")
    | {name: .change.after.name, enforce: .change.after.spec[0].rules[0].enforce}]'
```

Expected: a JSON array of exactly 3 objects, each with `"enforce": "TRUE"` and `name` ending in `storage.uniformBucketLevelAccess`, `iam.disableServiceAccountKeyCreation`, or `compute.requireOsLogin`.

- [ ] **Step 4: Commit**

```bash
git add tools/terraform/baselines/gcp/org_policy.tf
git commit -m "feat(lab-5-4): add org policy REJECT enforcement for CM-6/AC-2/AC-3"
```

---

## Task 4: Workload Identity Federation for GitHub Actions

**Files:**
- Create: `tools/terraform/baselines/gcp/workload_identity.tf`

**Interfaces:**
- Consumes: `var.project_id`, `var.github_repo` from Task 2.
- Produces: `google_iam_workload_identity_pool.github_actions`, `google_service_account.grc_gate` — referenced by Task 6 (`outputs.tf`).

- [ ] **Step 1: Paste this snippet into `workload_identity.tf`**

```hcl
# workload_identity.tf
# Control Coverage: IA-2(6), IA-8
# Framework: NIST 800-53 Rev 5 | FedRAMP Moderate

resource "google_iam_workload_identity_pool" "github_actions" {
  workload_identity_pool_id = "github-actions"
  display_name              = "GitHub Actions"
  description                = "WIF pool for grc-automation-toolkit CI"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_actions.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
  }

  # Security-critical: without this, any public GitHub repo could mint a
  # token that impersonates cgep-grc-gate-sa. Scopes the binding to one repo.
  attribute_condition = "assertion.repository == '${var.github_repo}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# IA-8: dedicated non-person entity for CI, no standing key (blocked by
# iam.disableServiceAccountKeyCreation from org_policy.tf).
resource "google_service_account" "grc_gate" {
  account_id   = "cgep-grc-gate-sa"
  display_name = "GRC gate CI service account (WIF, no keys)"
}

# Read-only. A future GCP-side CI gate that needs to apply would get a
# scoped custom role added then, not a broadening of this one.
resource "google_project_iam_member" "grc_gate_viewer" {
  project = var.project_id
  role    = "roles/viewer"
  member  = "serviceAccount:${google_service_account.grc_gate.email}"
}

resource "google_service_account_iam_member" "grc_gate_wif_binding" {
  service_account_id = google_service_account.grc_gate.name
  role                = "roles/iam.workloadIdentityUser"
  member              = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_actions.name}/attribute.repository/${var.github_repo}"
}
```

- [ ] **Step 2: Validate and plan**

```bash
terraform validate
terraform plan -out=tfplan
```

Expected: plan shows 5 resources to add, no errors.

- [ ] **Step 3: Assert the repo-scoped attribute_condition is present**

```bash
terraform show -json tfplan | jq '
  .resource_changes[]
  | select(.type == "google_iam_workload_identity_pool_provider")
  | .change.after.attribute_condition'
```

Expected: `"assertion.repository == 'Shayl-Taveras/grc-automation-toolkit'"`.

- [ ] **Step 4: Assert the service account has no key resources anywhere in the plan**

```bash
terraform show -json tfplan | jq '
  [.resource_changes[] | select(.type == "google_service_account_key")] | length'
```

Expected: `0` — confirms this baseline never creates a long-lived key, consistent with `iam.disableServiceAccountKeyCreation` from Task 3.

- [ ] **Step 5: Commit**

```bash
git add tools/terraform/baselines/gcp/workload_identity.tf
git commit -m "feat(lab-5-4): add repo-scoped WIF pool and CI service account for IA-2(6)/IA-8"
```

---

## Task 5: Data Access audit logging

**Files:**
- Create: `tools/terraform/baselines/gcp/audit_logs.tf`

**Interfaces:**
- Consumes: `var.project_id` from Task 2.
- Produces: none consumed by later tasks, evidence-only.

- [ ] **Step 1: Paste this snippet into `audit_logs.tf`**

```hcl
# audit_logs.tf
# Control Coverage: AU-3, AU-12
# Framework: NIST 800-53 Rev 5 | FedRAMP Moderate
# ADMIN_WRITE is always on regardless of config and needs no explicit block.

resource "google_project_iam_audit_config" "storage" {
  project = var.project_id
  service = "storage.googleapis.com"

  audit_log_config { log_type = "DATA_READ" }
  audit_log_config { log_type = "DATA_WRITE" }
  audit_log_config { log_type = "ADMIN_READ" }
}

resource "google_project_iam_audit_config" "kms" {
  project = var.project_id
  service = "cloudkms.googleapis.com"

  audit_log_config { log_type = "DATA_READ" }
  audit_log_config { log_type = "DATA_WRITE" }
  audit_log_config { log_type = "ADMIN_READ" }
}

resource "google_project_iam_audit_config" "iam" {
  project = var.project_id
  service = "iam.googleapis.com"

  audit_log_config { log_type = "DATA_READ" }
  audit_log_config { log_type = "DATA_WRITE" }
  audit_log_config { log_type = "ADMIN_READ" }
}
```

- [ ] **Step 2: Validate and plan**

```bash
terraform validate
terraform plan -out=tfplan
```

Expected: plan shows 3 resources to add, no errors.

- [ ] **Step 3: Assert all three services have all three log types enabled**

```bash
terraform show -json tfplan | jq '
  [.resource_changes[]
    | select(.type == "google_project_iam_audit_config")
    | {service: .change.after.service,
       log_types: [.change.after.audit_log_config[].log_type] | sort}]'
```

Expected: 3 objects, each `log_types` equal to `["ADMIN_READ", "DATA_READ", "DATA_WRITE"]`, services matching `storage.googleapis.com`, `cloudkms.googleapis.com`, `iam.googleapis.com`.

- [ ] **Step 4: Commit**

```bash
git add tools/terraform/baselines/gcp/audit_logs.tf
git commit -m "feat(lab-5-4): enable Data Access audit logs for AU-3/AU-12"
```

---

## Task 6: Outputs

**Files:**
- Create: `tools/terraform/baselines/gcp/outputs.tf`

**Interfaces:**
- Consumes: `google_iam_workload_identity_pool.github_actions`, `google_iam_workload_identity_pool_provider.github`, `google_service_account.grc_gate` from Task 4.

- [ ] **Step 1: Paste this snippet into `outputs.tf`**

```hcl
# outputs.tf
output "wif_pool_name" {
  description = "Full resource name of the WIF pool — CI wiring input."
  value       = google_iam_workload_identity_pool.github_actions.name
}

output "wif_provider_name" {
  description = "Full resource name of the WIF provider — CI wiring input (workload_identity_provider in a GitHub Actions auth step)."
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "grc_gate_service_account_email" {
  description = "Service account email a GitHub Actions job impersonates via WIF."
  value       = google_service_account.grc_gate.email
}
```

- [ ] **Step 2: Validate**

```bash
terraform validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 3: Commit**

```bash
git add tools/terraform/baselines/gcp/outputs.tf
git commit -m "feat(lab-5-4): add CI wiring outputs"
```

---

## Task 7: End-to-end apply, evidence capture, and README

**Files:**
- Create: `tools/terraform/baselines/gcp/README.md`
- Create (gitignored): `tools/terraform/baselines/gcp/evidence/lab-5-4/*.json`

- [ ] **Step 1: Full plan review before apply**

```bash
terraform plan
```

Expected: 11 resources to add total (3 org policy + 5 WIF/SA + 3 audit config), 0 to change, 0 to destroy.

- [ ] **Step 2: Apply**

```bash
terraform apply -auto-approve
```

Expected: `Apply complete! Resources: 11 added, 0 changed, 0 destroyed.`

- [ ] **Step 3: Capture evidence**

```bash
gcloud resource-manager org-policies list --project=$TF_VAR_project_id \
  > evidence/lab-5-4/org-policies.json
gcloud iam workload-identity-pools describe github-actions \
  --project=$TF_VAR_project_id --location=global --format=json \
  > evidence/lab-5-4/wif-pool.json
gcloud iam workload-identity-pools providers describe github \
  --project=$TF_VAR_project_id --location=global --workload-identity-pool=github-actions --format=json \
  > evidence/lab-5-4/wif-provider.json
gcloud projects get-iam-policy $TF_VAR_project_id --format=json \
  > evidence/lab-5-4/iam-audit-config.json
terraform show -json > evidence/lab-5-4/terraform-state.json
```

- [ ] **Step 4: Verify the WIF binding is scoped to the right repo (spot check the live resource, not just the plan)**

```bash
jq -r '.attributeCondition' evidence/lab-5-4/wif-provider.json
```

Expected: `assertion.repository == 'Shayl-Taveras/grc-automation-toolkit'`.

- [ ] **Step 5: Paste this snippet into `README.md`**

```markdown
# baselines/gcp

Terraform baseline that stands up GCP's project-scoped security backbone: Org Policy REJECT enforcement, a repo-scoped Workload Identity Federation pool for GitHub Actions, and Data Access audit logging. Mirrors `../aws/` — singleton project services, applied by hand in a sandbox, not gated in CI.

## Controls Enforced

| Control | Family | Mechanism |
|---------|--------|-----------|
| CM-6 | Configuration Settings | Org Policy `storage.uniformBucketLevelAccess` enforced project-wide |
| AC-2 | Account Management | Org Policy `iam.disableServiceAccountKeyCreation` enforced — no new SA keys can be minted |
| AC-3 | Access Enforcement | Org Policy `compute.requireOsLogin` enforced — no static SSH keys on Compute instances |
| IA-2(6) / IA-8 | Identification & Authentication | WIF pool scoped to `Shayl-Taveras/grc-automation-toolkit` via `attribute_condition`; service account has `roles/viewer` only, no standing key |
| AU-3 / AU-12 | Audit Content / Audit Generation | Data Access audit logs (DATA_READ, DATA_WRITE, ADMIN_READ) on for `storage.googleapis.com`, `cloudkms.googleapis.com`, `iam.googleapis.com` |

## Usage

\`\`\`bash
gcloud auth application-default login
export TF_VAR_project_id=project-fdec857e-a12f-46d6-b30
terraform init
terraform plan
terraform apply -auto-approve
\`\`\`

## Evidence

\`evidence/lab-5-4/\` holds the raw capture (gitignored — committed sample redacted if one is added later):

- \`org-policies.json\` — the three enforced constraints, live from the API
- \`wif-pool.json\` / \`wif-provider.json\` — pool and provider config, including the live \`attributeCondition\`
- \`iam-audit-config.json\` — project IAM policy showing the three \`auditConfigs\` entries
- \`terraform-state.json\` — full \`terraform show -json\` output, the audit artifact for all 11 resources in one file

Bundle, SHA-256 hash, sign with \`cosign sign-blob\` (keyless, Sigstore OIDC), and upload to the Lab 2.5 evidence vault — same manual pattern as Lab 5.2, since this lab isn't wired into \`grc-gate.yml\` either.

## Notes

- No taggable resources exist in this baseline — Org Policy, WIF, and audit config are all IAM/policy control-plane objects. GCP doesn't support labels on any of them, unlike the AWS baseline's tag-per-resource convention.
- Enforcing \`iam.disableServiceAccountKeyCreation\` blocks \`gcloud iam service-accounts keys create\` project-wide from this point forward, including in future labs against this project. WIF is the intended replacement path.
- No teardown step. Unlike CloudTrail/Security Hub, none of these three controls bill per-use — leave applied.
- Scoped to project only, no assumption of a GCP Organization. Security Command Center evidence capture is a separate follow-up if the project turns out to sit inside one.
```

- [ ] **Step 6: Commit**

```bash
git add tools/terraform/baselines/gcp/README.md
git commit -m "docs(lab-5-4): add gcp baseline README with control coverage table"
```

- [ ] **Step 7: Sign and upload evidence to the vault (mirrors Lab 5.2)**

```bash
tar -czf evidence-lab-5-4-$(date -u +%Y%m%dT%H%M%SZ).tar.gz -C evidence/lab-5-4 .
sha256sum evidence-lab-5-4-*.tar.gz > evidence-lab-5-4-*.tar.gz.sha256
cosign sign-blob --yes evidence-lab-5-4-*.tar.gz --bundle evidence-lab-5-4-*.tar.gz.sig.bundle
```

Upload the bundle to the same evidence vault bucket Lab 5.2 used, following that lab's manual upload steps. Record the resulting `vault:` / `run_id:` / `bundle_key:` / `version_id:` / `sha256:` block in the README's Evidence section, same format as `../aws/README.md`.

---

## Task 8: Update the GRC Project Log

**Files:**
- Modify: `GRC_Portfolio_Interview/GRC-Project-Log.md`

- [ ] **Step 1: Append a new entry** following the existing entry format in that file (one-line answer, 60-second talking point, frameworks with control IDs, key technical decisions, file path). Use the control table and design decisions from this plan and from `specs/2026-08-12-lab-5-4-gcp-security-baseline-design.md`. Do not commit this file — it's personal/local-only per `feedback_portfolio_no_commit` memory.

- [ ] **Step 2: Append a lessons-learned entry** to `GRC_Portfolio_Interview/GRC-Lessons-Learned.md` per `feedback_lessons_learned` memory — cover the `google_org_policy_policy` vs legacy `google_project_organization_policy` resource choice and the GCP-labels-don't-apply-here gap as the two non-obvious technical decisions from this lab.
