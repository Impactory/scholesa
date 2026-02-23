terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

# TODO: Create private GKE cluster with Workload Identity, node pools including GPU pool.
# Required:
# - private cluster (no public endpoint if possible)
# - workload identity enabled
# - GPU node pool (e.g., nvidia L4/A100 depending on region)
# - internal ingress (or internal load balancer) for inference services
# - network policy recommended

# NOTE: GPU drivers typically installed via GKE node image / DaemonSet (NVIDIA device plugin).
