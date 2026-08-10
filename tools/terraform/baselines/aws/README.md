# baselines/aws

Terraform baseline that stands up AWS's account-level compliance backbone: a multi-region CloudTrail with log-file validation, and Security Hub subscribed to NIST 800-53 Rev 5 and AWS Foundational Security Best Practices. Unlike the primitives in `../primitives/`, these are singleton account services, not per-resource modules — there's one of each per account, they're applied by hand in a sandbox, and torn down after evidence capture rather than gated in CI.

## Controls Enforced

| Control | Family | Mechanism |
|---------|--------|-----------|
| AU-2    | Audit Events | CloudTrail records management events across every region |
| AU-12   | Audit Record Generation | `is_multi_region_trail = true`, `include_global_service_events = true` |
| AU-10   | Non-repudiation | `enable_log_file_validation = true` — hourly AWS-signed digest files detect tampering |
| RA-5    | Vulnerability Monitoring and Scanning | Security Hub subscribed to NIST 800-53 Rev 5 and FSBP |
| SI-4    | System Monitoring | Security Hub's continuous control evaluation across the account |
| CM-2 / CM-6 / CM-8 | Baseline Configuration / Configuration Settings / Component Inventory | Not deployed by this module — the account already has an AWS-managed `default` Config recorder (service-linked role `AWSServiceRoleForConfig`). AWS allows one recorder per region, so `config.tf` is written but block-commented; the pre-existing recorder is the evidence instead. |

## Usage

```bash
eval "$(aws configure export-credentials --profile <your-sandbox> --format env)"
terraform init
terraform plan
terraform apply -auto-approve
```

Wait 10–20 minutes for the first wave of Security Hub findings to populate, then capture evidence:

```bash
aws cloudtrail get-trail-status --name cgep-lab-mgmt --region us-east-1 \
  > evidence/lab-5-2/cloudtrail-status.json
aws securityhub describe-hub --region us-east-1 \
  > evidence/lab-5-2/securityhub-hub.json
aws securityhub get-findings --region us-east-1 --max-results 50 \
  > evidence/lab-5-2/security-hub-findings.json
```

Tear down when evidence capture is done — Security Hub billing is per-check, not free:

```bash
terraform destroy -auto-approve
```

## Evidence

`evidence/lab-5-2/` holds the raw capture:

- `cloudtrail-status.json` — `IsLogging` / `LatestDeliveryTime` from the live trail
- `securityhub-hub.json` — hub ARN and subscription metadata
- `security-hub-findings.json` — first 50 findings (`--max-results 50`, not the full account total)
- `receipt.json` — chain-of-custody record for the signed vault upload

The findings, CloudTrail status, and hub metadata were bundled, SHA-256 hashed, signed with `cosign sign-blob` (keyless, Sigstore OIDC), and uploaded to the Lab 2.5 evidence vault — same pattern `grc-gate.yml` uses in CI, run by hand here since this lab isn't wired into that pipeline.

```
vault:      cgep-lab-grc-evidence-vault-cd91606f
run_id:     lab-5-2-20260810T021529Z
bundle_key: runs/lab-5-2-20260810T021529Z/evidence-lab-5-2-20260810T021529Z.tar.gz
version_id: _JKnRQeW5RsfmtIUOP.BUaynIghWZ68D
sha256:     a70c4264c1149b6ba2fdfae1be2ea2e7860ac3550dbc143a09ccfd05ad9f1a3b
```

First-wave results: 50 findings, 2 CRITICAL (`SSM documents should have the block public sharing setting enabled`, `IAM root user access key should not exist`), 6 HIGH, 15 MEDIUM, 2 LOW, 25 INFORMATIONAL. Security Hub also auto-subscribed the account to `cis-aws-foundations-benchmark` v1.2.0 by default (`enable_default_standards` defaults to `true` on `aws_securityhub_account`) — not something this config asked for, but real and reflected in the findings.

## Notes

- Security Hub billing is per check, not flat-rate — destroy promptly once evidence is captured.
- `config.tf` is intentionally disabled. If you apply this into an account with no pre-existing Config recorder, uncomment it — the resources (bucket, IAM role, recorder, delivery channel) are complete and ready to go.
- CloudTrail's `force_destroy = true` on the log bucket means `terraform destroy` deletes any log objects along with it — evidence must be captured before teardown, not after.
