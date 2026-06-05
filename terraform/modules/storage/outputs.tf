output "mlflow_artifacts_bucket" {
  description = "Name of the MLflow artifacts bucket."
  value       = google_storage_bucket.mlflow_artifacts.name
}

output "mlflow_artifacts_url" {
  description = "gs:// URL for the MLflow artifacts bucket."
  value       = "gs://${google_storage_bucket.mlflow_artifacts.name}"
}

output "models_bucket" {
  description = "Name of the trained-models bucket."
  value       = google_storage_bucket.models.name
}

output "models_url" {
  description = "gs:// URL for the trained-models bucket."
  value       = "gs://${google_storage_bucket.models.name}"
}

output "tfstate_bucket" {
  description = "Name of the Terraform remote-state bucket."
  value       = google_storage_bucket.tfstate.name
}

output "status_state_bucket" {
  description = "Name of the bucket gcsfuse-mounted into the Uptime Kuma container at /app/data."
  value       = google_storage_bucket.status_state.name
}
