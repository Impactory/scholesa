terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

# TODO: Create GCS buckets:
# - stt-uploads (TTL 30m)
# - tts-audio (TTL 1h)
# - audit-pack (retention per policy)
#
# IMPORTANT COPPA:
# - voice buckets must have lifecycle delete rules
# - voice buckets must NOT be included in long-term backups
