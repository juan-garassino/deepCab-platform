# Cloud Run service for the deepCab FastAPI app.
#
# IMPORTANT cross-repo contract:
# This Terraform module owns the SERVICE SHAPE (CPU/memory/scale/env/IAM).
# The 001-deepCab-api CI runs `gcloud run services update --image=...` which
# only swaps the container image; it never replaces the spec. That means
# `lifecycle.ignore_changes` MUST cover the container image — otherwise TF
# would revert every CI image push.

locals {
  service_labels = merge(
    var.labels,
    {
      env       = var.env
      managed   = "terraform"
      component = "cloud-run-api"
    }
  )
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

    dynamic "volumes" {
      for_each = length(var.cloudsql_instances) > 0 ? [1] : []
      content {
        name = "cloudsql"
        cloud_sql_instance {
          instances = var.cloudsql_instances
        }
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

      dynamic "env" {
        for_each = var.env_vars
        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = var.secret_env_vars
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = env.value
              version = "latest"
            }
          }
        }
      }

      dynamic "volume_mounts" {
        for_each = length(var.cloudsql_instances) > 0 ? [1] : []
        content {
          name       = "cloudsql"
          mount_path = "/cloudsql"
        }
      }

      startup_probe {
        http_get {
          path = "/healthz"
          port = var.container_port
        }
        initial_delay_seconds = 5
        period_seconds        = 2
        failure_threshold     = 30
        timeout_seconds       = 2
      }

      liveness_probe {
        http_get {
          path = "/healthz"
          port = var.container_port
        }
        period_seconds    = 10
        failure_threshold = 3
        timeout_seconds   = 2
      }
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  lifecycle {
    # CI updates the image via `gcloud run services update --image=...`.
    # TF must not revert that on the next plan.
    ignore_changes = [
      template[0].containers[0].image,
      client,
      client_version,
    ]
  }
}

# Allow unauthenticated invocations when desired (toggle per env).
resource "google_cloud_run_v2_service_iam_member" "public" {
  count    = var.allow_unauthenticated ? 1 : 0
  project  = var.project_id
  location = google_cloud_run_v2_service.this.location
  name     = google_cloud_run_v2_service.this.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
