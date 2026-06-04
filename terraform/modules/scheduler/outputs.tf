output "schedule_name" {
  description = "Cloud Scheduler job name."
  value       = google_cloud_scheduler_job.this.name
}

output "schedule_id" {
  description = "Full resource ID of the schedule."
  value       = google_cloud_scheduler_job.this.id
}

output "next_run_estimate" {
  description = "Configured cron expression — actual next-run timestamp must be queried via API."
  value       = google_cloud_scheduler_job.this.schedule
}
