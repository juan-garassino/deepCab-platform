output "secret_ids" {
  description = "Provisioned secret IDs."
  value       = [for s in google_secret_manager_secret.this : s.secret_id]
}

output "secret_names" {
  description = "Fully-qualified secret resource names (projects/.../secrets/...)."
  value       = { for k, s in google_secret_manager_secret.this : k => s.name }
}
