# Cloud Run service for MLflow tracking server.
#
# Backed by Cloud SQL Postgres (mlflow DB) + GCS for artifacts.
# The runtime SA needs:
#   - cloudsql.client      (mounted via Cloud SQL integration)
#   - storage.objectAdmin  (write artifacts to gs://deepcab-mlflow-artifacts-<env>)
#   - secretmanager.secretAccessor  (read mlflow-db-password)
#
# Cross-repo contract:
#   This module owns the SERVICE SHAPE. There is no CI workflow that swaps the
#   MLflow image — we pin it to a specific upstream tag and update via TF.

locals {
  service_labels = merge(
    var.labels,
    {
      env       = var.env
      managed   = "terraform"
      component = "cloud-run-mlflow"
    }
  )

  # MLflow connection URI: postgresql+psycopg2://USER:PASS@/DB?host=/cloudsql/INSTANCE
  # The password is wired via Secret Manager + the upstream MLflow image's
  # MLFLOW_BACKEND_STORE_URI env var.
  artifacts_uri = "gs://${var.artifacts_bucket}/"
}

resource "google_cloud_run_v2_service" "this" {
  project  = var.project_id
  name     = var.service_name
  location = var.region
  ingress  = var.ingress
  labels   = local.service_labels

  template {
    service_account = var.service_account_email

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    max_instance_request_concurrency = var.container_concurrency
    timeout                          = "${var.timeout_seconds}s"

    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = [var.cloudsql_instance]
      }
    }

    containers {
      image = var.image

      ports {
        name           = "http1"
        container_port = var.container_port
      }

      resources {
        limits = {
          cpu    = var.cpu
          memory = var.memory
        }
        cpu_idle          = var.min_instances == 0
        startup_cpu_boost = true
      }

      # ghcr.io/mlflow/mlflow ships without psycopg2. Install it on boot, then
      # exec mlflow server. Same hack as local docker-compose; swap for a
      # custom image baked from this base + `pip install psycopg2-binary` when
      # cold-start time becomes a real cost.
      command = ["bash", "-c"]
      args = [
        "pip install --no-cache-dir psycopg2-binary && exec mlflow server --host 0.0.0.0 --port ${var.container_port} --backend-store-uri 'postgresql+psycopg2://${var.db_user}:'$${DB_PASSWORD}'@/${var.db_name}?host=/cloudsql/${var.cloudsql_instance}' --default-artifact-root '${local.artifacts_uri}' --serve-artifacts"
      ]

      env {
        name  = "MLFLOW_TRACKING_URI"
        value = "http://0.0.0.0:${var.container_port}"
      }

      env {
        name = "DB_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = var.db_password_secret
            version = "latest"
          }
        }
      }

      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
      }

      startup_probe {
        http_get {
          path = "/"
          port = var.container_port
        }
        initial_delay_seconds = 5
        period_seconds        = 3
        failure_threshold     = 30
        timeout_seconds       = 3
      }

      liveness_probe {
        http_get {
          path = "/"
          port = var.container_port
        }
        period_seconds    = 30
        failure_threshold = 3
        timeout_seconds   = 3
      }
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  lifecycle {
    ignore_changes = [
      client,
      client_version,
    ]
  }
}

resource "google_cloud_run_v2_service_iam_member" "public" {
  count    = var.allow_unauthenticated ? 1 : 0
  project  = var.project_id
  location = google_cloud_run_v2_service.this.location
  name     = google_cloud_run_v2_service.this.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
