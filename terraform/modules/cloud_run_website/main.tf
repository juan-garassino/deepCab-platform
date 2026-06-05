# Cloud Run service for the deepCab static SPA (nginx-served Vite bundle).
#
# Cross-repo contract:
#   * 003-deepCab-website CI runs `gcloud run services update --image=...`
#     to swap the image on each release tag. This module owns the SHAPE
#     (CPU/memory/scale/IAM) and must `lifecycle.ignore_changes` the image.
#   * The runtime SA is shared with the api/job services. It needs no
#     elevated permissions to serve static files.

locals {
  service_labels = merge(
    var.labels,
    {
      env       = var.env
      managed   = "terraform"
      component = "cloud-run-website"
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

      startup_probe {
        http_get {
          path = "/"
          port = var.container_port
        }
        initial_delay_seconds = 1
        period_seconds        = 2
        failure_threshold     = 10
        timeout_seconds       = 2
      }

      liveness_probe {
        http_get {
          path = "/"
          port = var.container_port
        }
        period_seconds    = 30
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
    ignore_changes = [
      template[0].containers[0].image,
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
