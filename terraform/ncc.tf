resource "google_network_connectivity_hub" "primary" {
  name        = "${var.name_prefix}lab-connectivity-hub"
  description = "Hub connecting lab VPC networks"
  labels      = var.ncc_labels
}

resource "google_network_connectivity_spoke" "spoke_a" {
  name        = "${var.name_prefix}vpc-a-spoke"
  location    = "global"
  description = "VPC network spoke exporting its subnet CIDR"
  labels      = var.ncc_labels
  hub         = google_network_connectivity_hub.primary.id
  linked_vpc_network {

    include_export_ranges = [

      var.vpc_a_cidr
    ]
    uri = google_compute_network.vpc_network_a.self_link
  }
}

resource "google_network_connectivity_spoke" "spoke_b" {
  name        = "${var.name_prefix}vpc-b-spoke"
  location    = "global"
  description = "VPC network spoke exporting its subnet CIDR"
  labels      = var.ncc_labels
  hub         = google_network_connectivity_hub.primary.id
  linked_vpc_network {
    include_export_ranges = [

      var.vpc_b_cidr
    ]

    uri = google_compute_network.vpc_network_b.self_link
  }
}
