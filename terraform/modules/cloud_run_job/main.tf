# Cloud Run Job for the daily retrain. Same image as `cloud_run`, different
# entrypoint. Triggered by the `scheduler` module.

locals {
  job_labels = merge(
    var.labels,
    {
      env       = var.env
      managed   = "terraform"
      component = "cloud-run-job-retrain"
    }
  )
}

resource "google_cloud_run_v2_job" "this" {
  project  = var.project_id
  name     = var.job_name
  location = var.region
  labels   = local.job_labels

  template {
    parallelism = var.parallelism
    task_count  = var.task_count

    template {
      service_account = var.service_account_email
      timeout         = "${var.task_timeout_seconds}s"
      max_retries     = var.max_retries

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
        image   = var.image
        command = var.command
        args    = var.args

        resources {
          limits = {
            cpu    = var.cpu
            memory = var.memory
          }
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
      }
    }
  }

  lifecycle {
    # Same contract as cloud_run: CI does image-only updates.
    ignore_changes = [
      template[0].template[0].containers[0].image,
      client,
      client_version,
    ]
  }
}

# Scheduler SA gets run.invoker on this specific Job.
resource "google_cloud_run_v2_job_iam_member" "scheduler_invoker" {
  project  = var.project_id
  location = google_cloud_run_v2_job.this.location
  name     = google_cloud_run_v2_job.this.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${var.scheduler_sa_email}"
}
