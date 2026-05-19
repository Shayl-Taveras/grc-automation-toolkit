# Control Coverage: SC-28
# Framework: NIST 800-53 Rev 5
# Severity: High
# Enforces: Every google_storage_bucket must have CMEK via encryption { default_kms_key_name }
# Remediation: Add an encryption block referencing a google_kms_crypto_key resource
package compliance.sc28

import rego.v1

deny contains msg if {
      some resource in input.planned_values.root_module.resources
      resource.type == "google_storage_bucket"
      not has_cmek(resource)
      msg := sprintf(
          "[SC-28] %s: missing customer-managed encryption key. Remediation: add encryption { default_kms_key_name = ... }.",
          [resource.address],
      )
  }
  
  deny contains msg if {
      some child in input.planned_values.root_module.child_modules
      some resource in child.resources
      resource.type == "google_storage_bucket"
      not has_cmek(resource)
      msg := sprintf(
          "[SC-28] %s: missing customer-managed encryption key. Remediation: add encryption { default_kms_key_name = ... }.",
          [resource.address],
      )
  }

  has_cmek(resource) if {
      count(resource.values.encryption) > 0
      not empty_kms_key(resource.values.encryption[0])
  }

  empty_kms_key(enc) if enc.default_kms_key_name == ""
  empty_kms_key(enc) if enc.default_kms_key_name == null

