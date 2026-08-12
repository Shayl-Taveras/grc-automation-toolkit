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

```bash
gcloud auth application-default login
gcloud auth application-default set-quota-project project-fdec857e-a12f-46d6-b30
export TF_VAR_project_id=project-fdec857e-a12f-46d6-b30
terraform init
terraform plan
terraform apply -auto-approve
```

## Evidence

`evidence/lab-5-4/` holds the raw capture (gitignored — committed sample redacted if one is added later):

- `org-policies.json` — the three enforced constraints, live from the API
- `wif-pool.json` / `wif-provider.json` — pool and provider config, including the live `attributeCondition`
- `iam-audit-config.json` — project IAM policy showing the three `auditConfigs` entries
- `terraform-state.json` — full `terraform show -json` output, the audit artifact for all 11 resources in one file

Bundle, SHA-256 hash, sign with `cosign sign-blob` (keyless, Sigstore OIDC), and upload to the Lab 2.5 evidence vault — same manual pattern as Lab 5.2, since this lab isn't wired into `grc-gate.yml` either. The vault is AWS S3, cross-cloud from this GCP lab, same bucket Lab 5.2 used.

```
vault:      cgep-lab-grc-evidence-vault-cd91606f
run_id:     lab-5-4-20260812T173301Z
bundle_key: runs/lab-5-4-20260812T173301Z/evidence-lab-5-4-20260812T173301Z.tar.gz
version_id: VEBrm3OyPPUeCbW8l_LOOlxKY1AxxMRR
sha256:     8762d3834bae086138270e5b648a8b184268794e0da9720000110d52044592ae
```

## Notes

- No taggable resources exist in this baseline — Org Policy, WIF, and audit config are all IAM/policy control-plane objects. GCP doesn't support labels on any of them, unlike the AWS baseline's tag-per-resource convention.
- Enforcing `iam.disableServiceAccountKeyCreation` blocks `gcloud iam service-accounts keys create` project-wide from this point forward, including in future labs against this project. WIF is the intended replacement path.
- No teardown step. Unlike CloudTrail/Security Hub, none of these three controls bill per-use — leave applied.
- Two provider-level gotchas hit during first apply against this project, both now baked into `main.tf`/setup steps above:
  - `orgpolicy.googleapis.com` calls need `user_project_override = true` and `billing_project = var.project_id` on the `google` provider block — without it, ADC's quota project isn't actually applied to every API call, and requests silently fall back to an unrelated Google-internal default project, producing a misleading `SERVICE_DISABLED` 403 on the real project.
  - `cloudresourcemanager.googleapis.com` had never been enabled on this project (Lab 2.4 only touched GCS/KMS) — required for reading/writing project IAM policy (audit configs, `roles/viewer` binding, `data.google_project`).
- Creating the Org Policy resources also required `roles/orgpolicy.policyAdmin` at the **organization** level (`1067063206875`), not just `roles/owner` at the project level — project-level `roles/owner` did not include this permission in practice, and the role isn't grantable via `add-iam-policy-binding` on the project resource itself. This is now a standing org-level grant, not scoped to this lab.
- Scoped to project only. Confirmed after the fact that the project does sit inside an Organization (`1067063206875`) — the earlier assumption of "standalone project" in the design spec was wrong. Security Command Center evidence capture is a possible follow-up, now that an Organization is confirmed to exist.
