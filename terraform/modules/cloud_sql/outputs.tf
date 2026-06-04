output "instance_name" {
  description = "Cloud SQL instance name."
  value       = google_sql_database_instance.this.name
}

output "connection_name" {
  description = "Cloud SQL connection name (used by the Cloud SQL Proxy / Cloud Run integration)."
  value       = google_sql_database_instance.this.connection_name
}

output "private_ip_address" {
  description = "Private IP, empty when running with public IP."
  value       = google_sql_database_instance.this.private_ip_address
}

output "public_ip_address" {
  description = "Public IP, empty when running with private IP only."
  value       = google_sql_database_instance.this.public_ip_address
}

output "host" {
  description = "Best-effort host (private IP if set, else public)."
  value = (
    google_sql_database_instance.this.private_ip_address != "" ?
    google_sql_database_instance.this.private_ip_address :
    google_sql_database_instance.this.public_ip_address
  )
}

output "database_names" {
  description = "List of databases created inside the instance."
  value       = [for db in google_sql_database.this : db.name]
}

output "user_passwords" {
  description = "Map of username -> generated password. Surface into Secret Manager; do NOT log."
  value       = { for u, p in random_password.users : u => p.result }
  sensitive   = true
}
