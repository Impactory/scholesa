terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

# TODO: Provision Cloud Run services and bind service accounts.
# Required services:
# - scholesa-api
# - scholesa-ai (orchestrator)
# - scholesa-guard
# - scholesa-stt
# - scholesa-tts
# - scholesa-content
# - scholesa-compliance
#
# Key settings:
# - Ingress: internal/limited where possible (except api)
# - VPC connector for private access to GKE inference plane
# - Minimal env vars; NO vendor AI keys
