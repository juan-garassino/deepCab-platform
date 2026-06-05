output "service_name" {
  value = google_cloud_run_v2_service.this.name
}

output "service_url" {
  description = "Stable HTTPS URL — feed this into api/job MLFLOW_TRACKING_URI env var."
  value       = google_cloud_run_v2_service.this.uri
}

output "location" {
  value = google_cloud_run_v2_service.this.location
}
