variable "enabled" {
  description = "Module is a no-op when false (or when zone_name is empty)."
  type        = bool
  default     = false
}

variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "env" {
  description = "Environment short name. Used as subdomain prefix in non-prod."
  type        = string
}

variable "zone_name" {
  description = "Managed zone name (e.g. `deepcab-com`). Empty disables the module."
  type        = string
  default     = ""
}

variable "dns_name" {
  description = "DNS name of the managed zone, with trailing dot (e.g. `deepcab.com.`)."
  type        = string
  default     = ""
}

variable "create_zone" {
  description = "If true, create the managed zone. If false, look up an existing zone with var.zone_name."
  type        = bool
  default     = false
}

variable "records" {
  description = "Map of `subdomain` -> Cloud Run service URL (or any A-target as `value`). Subdomain is prepended to dns_name."
  type = map(object({
    type    = string
    ttl     = number
    rrdatas = list(string)
  }))
  default = {}
}
