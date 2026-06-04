output "enabled" {
  description = "Whether DNS records were managed."
  value       = var.enabled && var.zone_name != ""
}

output "zone_name" {
  description = "Effective managed zone name (created or referenced)."
  value       = local.zone_name
}

output "record_names" {
  description = "Fully-qualified DNS record names that were managed."
  value       = [for r in google_dns_record_set.records : r.name]
}
