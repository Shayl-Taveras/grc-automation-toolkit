# security_hub.tf
# Control Coverage: RA-5 (vulnerability scanning), SI-4 (system monitoring)
# Framework: NIST 800-53 Rev 5 | FedRAMP Moderate
#
# If Security Hub is already enabled in this account, `terraform apply` will
# hit ResourceConflictException. Import it instead:
#   terraform import aws_securityhub_account.this <ACCOUNT_ID>

resource "aws_securityhub_account" "this" {}

resource "aws_securityhub_standards_subscription" "nist_800_53" {
  standards_arn = "arn:aws:securityhub:${var.aws_region}::standards/nist-800-53/v/5.0.0"
  depends_on    = [aws_securityhub_account.this]
}

resource "aws_securityhub_standards_subscription" "fsbp" {
  standards_arn = "arn:aws:securityhub:${var.aws_region}::standards/aws-foundational-security-best-practices/v/1.0.0"
  depends_on    = [aws_securityhub_account.this]
}
