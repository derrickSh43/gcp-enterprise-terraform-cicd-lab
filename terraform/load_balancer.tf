resource "google_compute_health_check" "app_http_8080" {
  name = "${var.name_prefix}app-http-8080-health-check"

  http_health_check {
    port         = var.app_port
    request_path = var.health_check_path
  }
}

resource "google_compute_backend_service" "app_backend" {
  name                  = "${var.name_prefix}app-backend"
  protocol              = "HTTP"
  port_name             = "http"
  load_balancing_scheme = "EXTERNAL_MANAGED"

  health_checks = [
    google_compute_health_check.app_http_8080.id
  ]

  security_policy = google_compute_security_policy.app_waf.id
  backend {
    group           = google_compute_region_instance_group_manager.app_mig.instance_group
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }
}

resource "google_compute_url_map" "app_routes" {
  name            = "${var.name_prefix}app-routes"
  default_service = google_compute_backend_service.app_backend.id
}

data "google_compute_ssl_certificate" "lab_tls" {
  name = var.ssl_certificate_name
}

resource "google_compute_target_https_proxy" "app_https_proxy" {
  name    = "${var.name_prefix}app-https-proxy"
  url_map = google_compute_url_map.app_routes.id

  ssl_certificates = [
    data.google_compute_ssl_certificate.lab_tls.id
  ]
}

resource "google_compute_global_forwarding_rule" "app_https_listener" {
  name                  = "${var.name_prefix}app-https-listener"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_protocol           = "TCP"
  port_range            = "443"
  target                = google_compute_target_https_proxy.app_https_proxy.id
  ip_address            = google_compute_global_address.app_public_ip.id

}

resource "google_compute_global_address" "app_public_ip" {
  name = "${var.name_prefix}app-public-ip"
}
