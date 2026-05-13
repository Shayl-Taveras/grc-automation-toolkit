# Control Coverage: SC-28, CM-6, AC-3, AU-3
# Framework: NIST 800-53 Rev 5 | FedRAMP Moderate
# Phase 1 of Lab 05: provisions the ephemeral GKE cluster that hosts Kyverno.

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

data "google_project" "current" {
  project_id = var.project_id
}

locals {
  common_labels = {
    framework        = "nist-800-53-rev5"
    compliance_layer = "fedramp-moderate"
    environment      = var.environment
    managed_by       = "terraform"
  }

  control_labels = {
    sc28 = merge(local.common_labels, { control_id = "sc-28" })
    cm6  = merge(local.common_labels, { control_id = "cm-6" })
    ac3  = merge(local.common_labels, { control_id = "ac-3" })
    au3  = merge(local.common_labels, { control_id = "au-3" })
  }
}

