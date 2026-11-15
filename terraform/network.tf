resource "google_compute_network" "vpc_network_a" {
  project                 = var.project_id
  name                    = "${var.name_prefix}vpc-network-a"
  auto_create_subnetworks = false
  mtu                     = var.network_mtu
}

resource "google_compute_network" "vpc_network_b" {
  project                 = var.project_id
  name                    = "${var.name_prefix}vpc-network-b"
  auto_create_subnetworks = false
  mtu                     = var.network_mtu
}

resource "google_compute_subnetwork" "vpc_subnet_a" {
  name                     = "${var.name_prefix}vpc-subnet-central1-a"
  project                  = var.project_id
  region                   = var.region
  network                  = google_compute_network.vpc_network_a.id
  ip_cidr_range            = var.vpc_a_cidr
  private_ip_google_access = var.private_ip_google_access
}

resource "google_compute_subnetwork" "vpc_subnet_b" {
  name                     = "${var.name_prefix}vpc-subnet-central1-b"
  project                  = var.project_id
  region                   = var.region
  network                  = google_compute_network.vpc_network_b.id
  ip_cidr_range            = var.vpc_b_cidr
  private_ip_google_access = var.private_ip_google_access
}
