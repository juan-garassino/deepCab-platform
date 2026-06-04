# Cloud DNS — optional. Default disabled.
#
# Typical use:
#   * staging: api.staging.deepcab.com  CNAME -> ghs.googlehosted.com (Cloud Run domain mapping)
#   * prod:    api.deepcab.com          CNAME -> ghs.googlehosted.com
#
# For "raw" Cloud Run URLs (the *.run.app default), no DNS module is needed.

locals {
  enabled = var.enabled && var.zone_name != ""
}

resource "google_dns_managed_zone" "this" {
  count       = local.enabled && var.create_zone ? 1 : 0
  project     = var.project_id
  name        = var.zone_name
  dns_name    = var.dns_name
  description = "deepCab managed zone (${var.env})"

  labels = {
    env       = var.env
    managed   = "terraform"
    component = "dns"
  }
}

data "google_dns_managed_zone" "existing" {
  count   = local.enabled && !var.create_zone ? 1 : 0
  project = var.project_id
  name    = var.zone_name
}

locals {
  zone_name = local.enabled ? (
    var.create_zone ? google_dns_managed_zone.this[0].name : data.google_dns_managed_zone.existing[0].name
  ) : ""

  zone_dns_name = local.enabled ? (
    var.create_zone ? google_dns_managed_zone.this[0].dns_name : data.google_dns_managed_zone.existing[0].dns_name
  ) : ""
}

resource "google_dns_record_set" "records" {
  for_each = local.enabled ? var.records : {}

  project      = var.project_id
  managed_zone = local.zone_name
  name         = "${each.key}.${local.zone_dns_name}"
  type         = each.value.type
  ttl          = each.value.ttl
  rrdatas      = each.value.rrdatas
}
