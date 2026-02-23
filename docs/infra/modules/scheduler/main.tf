terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

# TODO: Cloud Scheduler job to call scholesa-compliance nightly with OIDC auth.
