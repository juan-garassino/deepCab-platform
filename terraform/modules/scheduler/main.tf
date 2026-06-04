# Cloud Scheduler HTTP job that fires the Cloud Run Job.
#
# Replaces `001/infra/gcp/scheduler/bootstrap.sh`.

resource "google_cloud_scheduler_job" "this" {
  project          = var.project_id
  region           = var.region
  name             = var.schedule_name
  description      = var.description
  schedule         = var.cron_schedule
  time_zone        = var.time_zone
  attempt_deadline = var.attempt_deadline
  paused           = var.paused

  retry_config {
    retry_count = var.retry_count
  }

  http_target {
    http_method = "POST"
    uri         = var.target_uri

    oauth_token {
      service_account_email = var.service_account_email
      scope                 = "https://www.googleapis.com/auth/cloud-platform"
    }
  }
}
