terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

# TODO: Create VPC, subnets, serverless VPC connector, NAT, firewall rules.
# Key goals:
# - Private access to GKE + internal load balancers
# - Controlled egress for Cloud Run through NAT
# - Firewall denylist/allowlist strategy to block external AI vendor domains
