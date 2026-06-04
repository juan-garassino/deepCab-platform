output "enabled" {
  description = "Whether the GKE module is active."
  value       = var.enabled
}

output "cluster_name" {
  description = "GKE cluster name (empty when disabled)."
  value       = var.enabled ? google_container_cluster.this[0].name : ""
}

output "cluster_endpoint" {
  description = "Public endpoint of the cluster control plane (empty when disabled)."
  value       = var.enabled ? google_container_cluster.this[0].endpoint : ""
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Base64-encoded CA cert. Use to build kubeconfig."
  value       = var.enabled ? google_container_cluster.this[0].master_auth[0].cluster_ca_certificate : ""
  sensitive   = true
}

output "location" {
  description = "Region the cluster lives in."
  value       = var.enabled ? google_container_cluster.this[0].location : ""
}
