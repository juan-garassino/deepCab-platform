# Cloud Run service for Uptime Kuma — the public status page.
#
# Runs `louislam/uptime-kuma:1` (Docker Hub — Cloud Run accepts docker.io).
# Probes the api/website/mlflow services on a schedule, renders the 90-day
# uptime bars (same UX as status.anthropic.com / status.openai.com).
#
# Persistence: SQLite at /app/data/kuma.db. Mounted on a GCS bucket via
# `gcsfuse` (Cloud Run's native support) so probe history survives revisions.
#
# Cost: ~$0/mo when showcase_mode=false (min=0, scales to zero between
# demos). ~$5/mo when showcase_mode=true (min=1 keeps probes running).

locals {
  service_labels = merge(
    var.labels,
    {
      env       = var.env
      managed   = "terraform"
      component = "cloud-run-status"
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

    volumes {
      name = "kuma-data"
      gcs {
        bucket    = var.state_bucket
        read_only = false
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

      volume_mounts {
        name       = "kuma-data"
        mount_path = "/app/data"
      }

      startup_probe {
        http_get {
          path = "/"
          port = var.container_port
        }
        initial_delay_seconds = 5
        period_seconds        = 5
        failure_threshold     = 30
        timeout_seconds       = 3
      }

      liveness_probe {
        http_get {
          path = "/"
          port = var.container_port
        }
        period_seconds    = 60
        failure_threshold = 3
        timeout_seconds   = 5
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
