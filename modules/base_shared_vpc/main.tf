# One environment's network: a Shared VPC host project with one VPC, one
# subnet, the firewall baseline and, if enabled, Cloud NAT. Called by
# 3-networks/envs/<env>. Network modules come from nasir19noor/terraform,
# pinned to a commit.

locals {
  network_name = "vpc-${var.env_code}-shared-base"
  subnet_name  = "sb-${var.env_code}-shared-base-${var.region}"
}

# --- Host project ------------------------------------------------------------

resource "random_id" "project_suffix" {
  byte_length = 2
}

resource "google_project" "host" {
  name                = "${var.project_prefix}-${var.env_code}-shared-base"
  project_id          = "${var.project_prefix}-${var.env_code}-shared-base-${random_id.project_suffix.hex}"
  folder_id           = var.folder_id
  billing_account     = var.billing_account
  auto_create_network = false
  deletion_policy     = "PREVENT"
}

resource "google_project_service" "compute" {
  project            = google_project.host.project_id
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

# --- VPC and subnet -----------------------------------------------------------

module "vpc" {
  source = "git::https://github.com/nasir19noor/terraform.git//gcp/modules/vpc?ref=664101e308a10cba234e276e2825690a067725b5"

  project_id      = google_project_service.compute.project
  network_name    = local.network_name
  routing_mode    = "GLOBAL"
  shared_vpc_host = true
  description     = "Shared VPC for ${var.env_code} environment"
}

# A plain resource: the subnets module of nasir19noor/terraform (at this ref)
# sets secondary_ip_range as an attribute, which google provider 6+ rejects.
# Flow logs are off (billed by volume).
resource "google_compute_subnetwork" "base" {
  project                  = google_project_service.compute.project
  name                     = local.subnet_name
  network                  = module.vpc.network_self_link
  region                   = var.region
  ip_cidr_range            = var.subnet
  private_ip_google_access = true # Google APIs without a public IP
}

# --- Firewall baseline --------------------------------------------------------
# Ingress that no rule allows is denied by GCP's implied rule; egress is
# allowed. With no target tags, each rule applies to every VM in the VPC.

module "fw_allow_iap_ssh" {
  source = "git::https://github.com/nasir19noor/terraform.git//gcp/modules/firewall?ref=664101e308a10cba234e276e2825690a067725b5"

  project       = google_project_service.compute.project
  network       = module.vpc.network_name
  name          = "fw-${var.env_code}-shared-base-allow-iap-ssh"
  description   = "SSH through Identity-Aware Proxy"
  protocol      = "tcp"
  ports         = ["22"]
  source_ranges = var.iap_ranges
}

module "fw_allow_internal" {
  source = "git::https://github.com/nasir19noor/terraform.git//gcp/modules/firewall?ref=664101e308a10cba234e276e2825690a067725b5"

  project       = google_project_service.compute.project
  network       = module.vpc.network_name
  name          = "fw-${var.env_code}-shared-base-allow-internal"
  description   = "Traffic between VMs inside ${var.cidr}"
  protocol      = "all"
  source_ranges = [var.cidr]
}

# --- Cloud NAT (optional, billed hourly) ---------------------------------------

resource "google_compute_router" "nat" {
  count   = var.nat ? 1 : 0
  project = google_project_service.compute.project
  name    = "cr-${var.env_code}-shared-base-${var.region}"
  region  = var.region
  network = module.vpc.network_self_link
}

resource "google_compute_router_nat" "nat" {
  count                              = var.nat ? 1 : 0
  project                            = google_project_service.compute.project
  name                               = "nat-${var.env_code}-shared-base-${var.region}"
  router                             = google_compute_router.nat[0].name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
