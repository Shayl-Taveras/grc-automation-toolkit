# org_policy.tf
# Control Coverage: CM-6, AC-2, AC-3
# Framework: NIST 800-53 Rev 5 | FedRAMP Moderate

# CM-6: no bucket in the project may use legacy ACLs.
resource "google_org_policy_policy" "uniform_bucket_level_access" {
  name   = "projects/${var.project_id}/policies/storage.uniformBucketLevelAccess"
  parent = "projects/${var.project_id}"

  spec {
    rules {
      enforce = "TRUE"
    }
  }
}

# AC-2: no new service account keys can be minted project-wide.
# This forces WIF / short-lived credentials for anything created after apply,
# including future manual `gcloud iam service-accounts keys create` calls.
resource "google_org_policy_policy" "disable_sa_key_creation" {
  name   = "projects/${var.project_id}/policies/iam.disableServiceAccountKeyCreation"
  parent = "projects/${var.project_id}"

  spec {
    rules {
      enforce = "TRUE"
    }
  }
}

# AC-3: no static SSH keys on Compute instances project-wide.
resource "google_org_policy_policy" "require_os_login" {
  name   = "projects/${var.project_id}/policies/compute.requireOsLogin"
  parent = "projects/${var.project_id}"

  spec {
    rules {
      enforce = "TRUE"
    }
  }
}
