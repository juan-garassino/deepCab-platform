terraform {
  required_version = ">= 1.5.0"

  # Backend bucket must exist before `terraform init` — bootstrap docs in
  # ../../../docs/RUNBOOK.md walk through creating it once per environment.
  backend "gcs" {
    bucket = "deepcab-tfstate-dev"
    prefix = "envs/dev"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}
