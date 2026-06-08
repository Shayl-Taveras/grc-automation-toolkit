# Compliance Policy Library — Labs 3.3 / 3.4

Rego policies for pre-apply Terraform plan validation. Policies run against
`terraform show -json` output before any `terraform apply`. Three controls,
six policies (GCP + AWS variants), zero screenshots.

---

## Policies

| File | Control | Cloud | Severity | What It Enforces |
|------|---------|-------|----------|-----------------|
| `sc28_encryption.rego` | SC-28 | GCP | High | Every `google_storage_bucket` must have CMEK via `encryption { default_kms_key_name }` |
| `sc28_encryption_aws.rego` | SC-28 | AWS | High | Every `aws_s3_bucket` must have a matching `aws_s3_bucket_server_side_encryption_configuration` |
| `ac3_no_public.rego` | AC-3 | GCP | Critical | Buckets require `uniform_bucket_level_access=true` and `public_access_prevention=enforced`; firewall rules must not expose ports 22 or 3389 to `0.0.0.0/0` |
| `ac3_no_public_aws.rego` | AC-3 | AWS | Critical | Every `aws_s3_bucket` must have an `aws_s3_bucket_public_access_block` with all four flags true |
| `cm6_required_tags.rego` | CM-6 | GCP | Medium | All taggable resources must carry `project`, `environment`, `managed_by`, and `compliance_scope` labels |
| `cm6_required_tags_aws.rego` | CM-6 | AWS | Medium | All taggable resources must carry `Project`, `Environment`, `ManagedBy`, and `ComplianceScope` tags |

---

## Running OPA Unit Tests

```bash
opa test -v policies/
```

Expected: `PASS: 8/8`

---

## Evaluating Against a Plan (Conftest)

Generate the plan first:

```bash
terraform plan -out=tfplan
terraform show -json tfplan > plan.json
```

Run all AWS namespaces:

```bash
for ns in compliance.sc28_aws compliance.ac3_aws compliance.cm6_aws ; do
  echo "=== $ns ==="
  conftest test --policy policies --namespace $ns plan.json
done
```

Or use the wrapper script (also called by CI in Lab 4.3):

```bash
./scripts/policy-gate.sh --workspace <terraform-workspace-path>
```

---

## Remediation

Every deny message includes the resource address, the NIST control ID, and the exact fix.
The developer gets the remediation without filing a GRC ticket.
