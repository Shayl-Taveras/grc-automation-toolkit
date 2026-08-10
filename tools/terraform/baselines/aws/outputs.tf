# outputs.tf
output "cloudtrail_trail_arn" {
  description = "ARN of the multi-region management trail (AU-2/AU-12/AU-10 evidence anchor)."
  value       = aws_cloudtrail.mgmt.arn
}

output "cloudtrail_bucket_name" {
  description = "S3 bucket receiving CloudTrail logs."
  value       = aws_s3_bucket.trail.id
}

output "securityhub_account_arn" {
  description = "ARN of the Security Hub account subscription."
  value       = aws_securityhub_account.this.arn
}
