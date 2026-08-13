# oscal/

OSCAL layer of the GRC Automation Toolkit capstone (Lab 6.1). Describes toolkit
components in NIST's machine-readable control format so an assessor can
traverse from a control catalog to a component's evidence without a
conversation.

## Contents

- `components/compliant-s3.json` — Component Definition for
  `tools/terraform/primitives/compliant-s3`. Declares four implemented
  requirements (SC-28, AC-3, AU-3, CM-6), each with the exact Terraform
  resource that satisfies it and a `links[rel=evidence]` pointing at a
  signed, immutable bundle in the evidence vault.
- `profiles/cge-p-minimum.json` — Profile selecting the same four controls
  from the NIST 800-53 Rev 5 catalog. Resolves via
  `trestle author profile-resolve` into a flat control list an SSP would
  import.
- `evidence/lab-6-1/trestle-validate.txt` — Captured output of
  `trestle validate` on both models, `trestle author profile-resolve`, and
  `scripts/verify-evidence.sh` against the linked evidence bundle.

## Where the evidence lives

Every evidence link in `components/compliant-s3.json` points at the vault
bucket `cgep-lab-grc-evidence-vault-cd91606f`, under `runs/<github-run-id>/`.
Each object there is:

- Uploaded by `.github/workflows/grc-gate.yml` on every PR (or manual
  `workflow_dispatch`) against `tools/terraform/primitives/compliant-s3`.
- Signed with Cosign; verifiable against the Sigstore Rekor transparency log.
- Held under S3 Object Lock, `COMPLIANCE` mode, 400-day default retention
  (`tools/terraform/primitives/evidence-vault`, `retention_days` /
  `lock_mode` variables) — undeletable by anyone, including account root,
  until the retention date passes.

To re-verify the chain yourself:

```bash
EVIDENCE_VAULT=cgep-lab-grc-evidence-vault-cd91606f scripts/verify-evidence.sh <run_id>
```

`<run_id>` is the GitHub Actions run ID embedded in each evidence `href`.
A successful run prints `CHAIN INTACT` after checking integrity (SHA-256),
authenticity (Cosign + Rekor), and preservation (Object Lock retention).

## Known limitation

`sc-28`, `ac-3`, and `cm-6` are gated by dedicated Conftest namespaces in
`grc-gate.yml` (`compliance.sc28_aws`, `compliance.ac3_aws`,
`compliance.cm6_aws`) — a PR that regresses those controls fails CI.
`au-3` is not yet gated by its own policy; its evidence is the
`aws_s3_bucket_logging.primary` resource present in the bundled
`plan.json`, but nothing currently blocks a PR that removes it. Adding an
`au3_aws` Conftest namespace is a natural next step before the capstone.
