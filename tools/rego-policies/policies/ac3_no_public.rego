# Control Coverage: AC-3
# Framework: NIST 800-53 Rev 5
# Severity: Critical
# Enforces: GCS buckets must set uniform_bucket_level_access=true and public_access_prevention=enforced
#           Firewall rules must not expose ports 22 or 3389 to 0.0.0.0/0
# Remediation: Lock down bucket access settings; narrow or remove open firewall rules
package compliance.ac3

  import rego.v1

  deny contains msg if {
      resource := bucket_resource[_]
      not bucket_locked_down(resource)
      msg := sprintf("[AC-3] %s: bucket allows public access. Set uniform_bucket_level_access=true and public_access_prevention=enforced.",[resource.address]) 
  }

  bucket_resource contains r if {
      some r in input.planned_values.root_module.resources
      r.type == "google_storage_bucket"
  }

  bucket_resource contains r if {
      some child in input.planned_values.root_module.child_modules
      some r in child.resources
      r.type == "google_storage_bucket"
  }

  bucket_locked_down(r) if {
      r.values.uniform_bucket_level_access == true
      r.values.public_access_prevention == "enforced"
  }

  mgmt_port(p) if p == "22"
  mgmt_port(p) if p == "3389"

  public_range(s) if s == "0.0.0.0/0"
  public_range(s) if s == "*"   

  deny contains msg if {
      some r in input.planned_values.root_module.resources
      r.type == "google_compute_firewall"
      r.values.direction == "INGRESS"
      some src in r.values.source_ranges
      public_range(src)
      some allow in r.values.allow
      some port in allow.ports
      mgmt_port(port)
      msg := sprintf("[AC-3] %s: port %s open to %s. Remove or narrow source_ranges.", [r.address, port, src])
  }
