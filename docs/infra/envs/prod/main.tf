terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
  # TODO: configure backend for state (GCS recommended)
}

provider "google" {
  project = var.project_id
  region  = var.region
}

module "network" {
  source      = "../../modules/network"
  project_id  = var.project_id
  region      = var.region
  environment = var.environment
  name_prefix = var.name_prefix
}

module "gke" {
  source      = "../../modules/gke"
  project_id  = var.project_id
  region      = var.region
  environment = var.environment
  name_prefix = var.name_prefix
  vpc_name    = module.network.vpc_name
  subnet_name = module.network.subnet_name
}

module "storage" {
  source      = "../../modules/storage"
  project_id  = var.project_id
  region      = var.region
  environment = var.environment
  name_prefix = var.name_prefix
}

module "cloudrun" {
  source              = "../../modules/cloudrun"
  project_id          = var.project_id
  region              = var.region
  environment         = var.environment
  name_prefix         = var.name_prefix
  serverless_connector = module.network.serverless_connector
}

# TODO: wire compliance scheduler once cloudrun outputs provide compliance URL.
