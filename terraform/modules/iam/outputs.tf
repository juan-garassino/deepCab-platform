output "extras_count" {
  description = "Number of extra IAM bindings provisioned."
  value       = length(var.extra_project_bindings)
}

output "budget_enabled" {
  description = "Whether a billing budget was provisioned."
  value       = length(google_billing_budget.this) > 0
}
