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
