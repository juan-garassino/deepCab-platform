output "job_name" {
  description = "Cloud Run Job name."
  value       = google_cloud_run_v2_job.this.name
}

output "job_id" {
  description = "Fully-qualified job resource ID."
  value       = google_cloud_run_v2_job.this.id
}

output "location" {
  description = "Region the job lives in."
  value       = google_cloud_run_v2_job.this.location
}

output "execute_uri" {
  description = "HTTPS URI used by Cloud Scheduler to fire the job."
  value       = "https://${google_cloud_run_v2_job.this.location}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${var.project_id}/jobs/${google_cloud_run_v2_job.this.name}:run"
}
