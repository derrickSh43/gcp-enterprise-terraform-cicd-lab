resource "google_compute_firewall" "allow_vpc_a_to_vpc_b" {
  name          = "${var.name_prefix}allow-vpc-a-to-vpc-b"
  network       = google_compute_network.vpc_network_b.name
  direction     = "INGRESS"
  source_ranges = [var.vpc_a_cidr]


  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = [tostring(var.app_port)]
  }


}

resource "google_compute_firewall" "allow_public_https" {
  name          = "${var.name_prefix}allow-public-https"
  network       = google_compute_network.vpc_network_a.name
  direction     = "INGRESS"
  source_ranges = var.public_https_source_ranges


  allow {
    protocol = "tcp"
    ports    = ["443"]
  }


}

resource "google_compute_firewall" "allow_lb_health_checks" {
  name      = "${var.name_prefix}allow-lb-health-checks"
  network   = google_compute_network.vpc_network_a.name
  direction = "INGRESS"

  # Google Cloud load balancer and health check ranges
  source_ranges = var.lb_health_check_source_ranges

  allow {
    protocol = "tcp"
    ports    = [tostring(var.app_port)]
  }

  description = "Allow Google load balancer and health check traffic to MIG instances"
}

resource "google_compute_firewall" "allow_vpc_b_to_vpc_a_icmp" {
  name          = "${var.name_prefix}allow-vpc-b-to-vpc-a-icmp"
  network       = google_compute_network.vpc_network_a.name
  direction     = "INGRESS"
  source_ranges = [var.vpc_b_cidr]
  target_tags   = ["ncc-test"]

  allow {
    protocol = "icmp"
  }
}

resource "google_compute_firewall" "allow_iap_ssh" {
  for_each = {
    vpc_a = google_compute_network.vpc_network_a.name
    vpc_b = google_compute_network.vpc_network_b.name
  }

  name          = "${var.name_prefix}allow-iap-ssh-${replace(each.key, "_", "-")}"
  network       = each.value
  direction     = "INGRESS"
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["ncc-test"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}
