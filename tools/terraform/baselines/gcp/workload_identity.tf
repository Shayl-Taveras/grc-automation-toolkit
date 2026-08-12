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
