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


# Control: SC-28 (Cryptographic Protection at Rest)
# Application-layer secrets encryption for GKE etcd via customer-managed key.

resource "google_kms_key_ring" "sc28_gke_keyring" {
  name     = "sc28-${var.cluster_name}-keyring"
  location = var.region
}

resource "google_kms_crypto_key" "sc28_gke_secrets" {
  name            = "sc28-${var.cluster_name}-secrets"
  key_ring        = google_kms_key_ring.sc28_gke_keyring.id
  rotation_period = "7776000s" # 90 days

  labels = local.control_labels.sc28
}

resource "google_kms_crypto_key_iam_member" "gke_service_agent_kms" {
  crypto_key_id = google_kms_crypto_key.sc28_gke_secrets.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${data.google_project.current.number}@container-engine-robot.iam.gserviceaccount.com"
}