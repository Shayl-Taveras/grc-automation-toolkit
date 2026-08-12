terraform {
  required_version = ">= 1.6"
  required_providers {
    google = { source = "hashicorp/google", version = "~> 5.0" }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region

  # ADC's quota_project_id isn't automatically applied to every API call by
  # this provider. Without this, orgpolicy.googleapis.com calls fall back to
  # a Google-internal default quota project instead of var.project_id, and
  # fail with a misleading "SERVICE_DISABLED" 403 even though the real
  # project has the API enabled.
  user_project_override = true
  billing_project        = var.project_id
}

data "google_project" "current" {
  project_id = var.project_id
}
