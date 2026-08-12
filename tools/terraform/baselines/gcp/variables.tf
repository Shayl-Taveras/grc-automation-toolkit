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
