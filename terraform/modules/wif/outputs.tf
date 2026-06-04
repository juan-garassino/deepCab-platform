output "pool_name" {
  description = "Fully-qualified Workload Identity Pool resource name."
  value       = google_iam_workload_identity_pool.github.name
}

output "provider_name" {
  description = "Fully-qualified provider name, used in GitHub Actions `workload_identity_provider`."
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "deployer_sa_email" {
  description = "Email of the deployer SA. Set as `service_account` in GH Actions auth step."
  value       = google_service_account.deployer.email
}

output "runtime_sa_email" {
  description = "Email of the runtime SA. Attached to Cloud Run services."
  value       = google_service_account.runtime.email
}

output "scheduler_sa_email" {
  description = "Email of the Cloud Scheduler SA."
  value       = google_service_account.scheduler.email
}

output "terraform_sa_email" {
  description = "Email of the Terraform CI SA (used by this platform repo's workflows)."
  value       = google_service_account.terraform.email
}
