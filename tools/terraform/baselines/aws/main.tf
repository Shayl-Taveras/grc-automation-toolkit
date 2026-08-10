# main.tf
terraform {
  required_version = ">= 1.6"
  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 5.0" }
    random = { source = "hashicorp/random", version = "~> 3.6" }
  }
}

provider "aws" {
  region = var.aws_region

  # CM-6: required compliance tags applied to every taggable resource by default.
  default_tags {
    tags = {
      Project         = var.project_name
      Environment     = var.environment
      ManagedBy       = "terraform"
      ComplianceScope = "cge-p-lab"
    }
  }
}

data "aws_caller_identity" "current" {}

resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  trail_name = "${var.project_name}-mgmt"
}
