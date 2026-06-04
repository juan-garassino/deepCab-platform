# GCS buckets backing the deepCab stack.
#
# - mlflow-artifacts: artifact store for MLflow runs (referenced by MLFLOW_ARTIFACT_URI)
# - deepcab-models:    trained-model artifacts written by the retrain job / registry.dispatcher
# - tfstate:           remote state bucket. CHICKEN-AND-EGG — created manually first
#                      (see RUNBOOK.md), then imported. The TF block here makes the
#                      bucket subject to drift detection after import.

locals {
  bucket_labels = merge(
    var.labels,
    {
      env       = var.env
      managed   = "terraform"
      component = "deepcab-platform"
    }
  )
}

resource "google_storage_bucket" "mlflow_artifacts" {
  name                        = "${var.name_prefix}-mlflow-artifacts-${var.env}"
  project                     = var.project_id
  location                    = var.region
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  force_destroy               = var.force_destroy
  labels                      = local.bucket_labels

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = var.mlflow_artifacts_lifecycle_days
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  lifecycle_rule {
    condition {
      num_newer_versions = 5
    }
    action {
      type = "Delete"
    }
  }
}

resource "google_storage_bucket" "models" {
  name                        = "${var.name_prefix}-models-${var.env}"
  project                     = var.project_id
  location                    = var.region
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  force_destroy               = var.force_destroy
  labels                      = local.bucket_labels

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = var.models_archive_days
    }
    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
  }
}

resource "google_storage_bucket" "tfstate" {
  # The state bucket is bootstrapped manually before `terraform init`;
  # this resource exists so it becomes part of state once imported, allowing
  # drift detection and labels/versioning to be managed via TF going forward.
  name                        = "${var.name_prefix}-tfstate-${var.env}"
  project                     = var.project_id
  location                    = var.region
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  force_destroy               = false # never auto-delete state
  labels                      = local.bucket_labels

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      num_newer_versions = 30
      age                = 30
    }
    action {
      type = "Delete"
    }
  }
}
