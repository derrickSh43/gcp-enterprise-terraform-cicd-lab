resource "google_compute_instance_template" "app_template" {
  name_prefix  = "${var.name_prefix}app-template-"
  machine_type = var.app_machine_type
  region       = var.region

  disk {
    source_image = var.app_image
    auto_delete  = true
    boot         = true
    disk_size_gb = var.app_disk_size_gb
  }

  network_interface {
    subnetwork = google_compute_subnetwork.vpc_subnet_a.id

    access_config {}
  }

  service_account {
    email  = google_service_account.app_vm_identity.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    startup-script = <<-EOF
      #!/bin/bash
      apt-get update && apt-get install -y nginx
      sed -i 's/listen 80 default_server;/listen ${var.app_port} default_server;/' /etc/nginx/sites-available/default
      echo "Hello from $(hostname)" > /var/www/html/index.html
      systemctl restart nginx
    EOF
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_region_instance_group_manager" "app_mig" {
  name               = "${var.name_prefix}app-regional-mig"
  region             = var.region
  base_instance_name = "${var.name_prefix}app-node"
  target_size        = var.app_instance_count

  version {
    instance_template = google_compute_instance_template.app_template.id
  }

  named_port {
    name = "http"
    port = var.app_port
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.app_http_8080.id
    initial_delay_sec = var.app_initial_delay_sec
  }
}

resource "google_compute_instance" "app_vm" {
  name         = "${var.name_prefix}app-vm"
  machine_type = var.vm_machine_type
  zone         = var.zone

  tags = distinct(concat(var.vm_tags, ["ncc-test"]))

  boot_disk {
    initialize_params {
      image  = var.vm_image
      labels = var.vm_disk_labels
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.vpc_subnet_a.id

    # Private IP only; SSH is tunneled through IAP.
  }

  metadata = merge(var.vm_metadata, {
    enable-oslogin         = "TRUE"
    block-project-ssh-keys = "TRUE"
  })

  metadata_startup_script = var.vm_startup_script

  depends_on = [google_project_service.test_access]

  service_account {
    email  = google_service_account.app_vm_identity.email
    scopes = ["cloud-platform"]
  }
}

# Small private-only endpoint for testing the second NCC spoke.
resource "google_compute_instance" "test_vm_b" {
  name         = "${var.name_prefix}test-vm-b"
  machine_type = var.test_vm_b_machine_type
  zone         = var.zone
  tags         = ["ncc-test"]

  boot_disk {
    initialize_params {
      image = var.vm_image
      size  = 10
      type  = "pd-standard"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.vpc_subnet_b.id
    # No access_config: this VM has no public IP.
  }

  metadata = {
    enable-oslogin         = "TRUE"
    block-project-ssh-keys = "TRUE"
  }

  service_account {
    email  = google_service_account.app_vm_identity.email
    scopes = ["cloud-platform"]
  }

  depends_on = [google_project_service.test_access]
}

locals {
  test_vms = {
    vpc_a = google_compute_instance.app_vm
    vpc_b = google_compute_instance.test_vm_b
  }
}
