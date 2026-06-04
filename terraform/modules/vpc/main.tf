# VPC + private services connection + Cloud NAT.
#
# Needed by:
#   * Cloud SQL private IP (private services connection)
#   * Cloud Run direct VPC egress (when min_instances > 0 + private SQL)
#   * GKE (when enabled)
#
# Gated by var.enabled so dev can skip the whole thing.

locals {
  enabled = var.enabled
}

resource "google_compute_network" "this" {
  count                           = local.enabled ? 1 : 0
  project                         = var.project_id
  name                            = var.network_name
  auto_create_subnetworks         = false
  routing_mode                    = "REGIONAL"
  delete_default_routes_on_create = false
}

resource "google_compute_subnetwork" "primary" {
  count                    = local.enabled ? 1 : 0
  project                  = var.project_id
  name                     = "${var.network_name}-${var.region}"
  region                   = var.region
  network                  = google_compute_network.this[0].id
  ip_cidr_range            = var.subnet_cidr
  private_ip_google_access = true
}

# Reserve a range for Google-managed services (Cloud SQL, Memorystore, etc.)
resource "google_compute_global_address" "private_services" {
  count         = local.enabled ? 1 : 0
  project       = var.project_id
  name          = "${var.network_name}-private-services"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  address       = split("/", var.private_services_cidr)[0]
  network       = google_compute_network.this[0].id
}

resource "google_service_networking_connection" "private_services" {
  count                   = local.enabled ? 1 : 0
  network                 = google_compute_network.this[0].id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_services[0].name]
}

# Cloud NAT for outbound internet from private nodes.
resource "google_compute_router" "nat" {
  count   = local.enabled && var.enable_nat ? 1 : 0
  project = var.project_id
  name    = "${var.network_name}-router"
  region  = var.region
  network = google_compute_network.this[0].id
}

resource "google_compute_router_nat" "nat" {
  count                              = local.enabled && var.enable_nat ? 1 : 0
  project                            = var.project_id
  name                               = "${var.network_name}-nat"
  router                             = google_compute_router.nat[0].name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
