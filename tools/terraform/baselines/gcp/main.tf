terraform {
  required_version = ">= 1.6"
  required_providers {
    google = { source = "hashicorp/google", version = "~> 5.0" }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_project" "current" {
  project_id = var.project_id
}

variable "project_id" {
  description = "The GCP project ID to manage resources in."
  type        = string
}

variable "region" {
  description = "The GCP region to use for resources."
  type        = string
}
