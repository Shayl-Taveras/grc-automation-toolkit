# variables.tf
variable "project_name" {
  type        = string
  description = "Short project identifier. Becomes part of the trail name, bucket names, and the Project tag."
  default     = "cgep-lab"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,20}$", var.project_name))
    error_message = "project_name must be 3-21 lowercase alphanumerics or hyphens, starting with a letter."
  }
}

variable "environment" {
  type        = string
  description = "Deployment environment. Drives the Environment tag."
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "aws_region" {
  type        = string
  description = "Region Security Hub, Config, and the CloudTrail home region are deployed to. The trail itself is multi-region regardless of this value."
  default     = "us-east-1"
}
