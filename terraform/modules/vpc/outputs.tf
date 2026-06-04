output "enabled" {
  description = "Whether the VPC module actually provisioned anything."
  value       = var.enabled
}

output "network_id" {
  description = "Full ID of the VPC network (empty string if disabled)."
  value       = var.enabled ? google_compute_network.this[0].id : ""
}

output "network_self_link" {
  description = "Self-link of the VPC network."
  value       = var.enabled ? google_compute_network.this[0].self_link : ""
}

output "subnet_id" {
  description = "ID of the primary regional subnet."
  value       = var.enabled ? google_compute_subnetwork.primary[0].id : ""
}

output "private_services_connection" {
  description = "Service Networking connection ID (input for Cloud SQL private IP)."
  value       = var.enabled ? google_service_networking_connection.private_services[0].id : ""
}
