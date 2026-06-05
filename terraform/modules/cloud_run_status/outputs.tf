output "service_name" {
  value = google_cloud_run_v2_service.this.name
}

output "service_url" {
  description = "Public status page URL — share this for the showcase."
  value       = google_cloud_run_v2_service.this.uri
}

output "location" {
  value = google_cloud_run_v2_service.this.location
}
