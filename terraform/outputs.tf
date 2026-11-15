output "connectivity_test" {
  description = "Private test VM endpoints and NCC details for the README connectivity checks."
  value = {
    project_id      = var.project_id
    region          = var.region
    hub_name        = google_network_connectivity_hub.primary.name
    route_table     = "default-route-table"
    expected_cidrs  = [var.vpc_a_cidr, var.vpc_b_cidr]
    iap_ssh_members = var.iap_ssh_members
    vm_a = {
      name       = google_compute_instance.app_vm.name
      zone       = google_compute_instance.app_vm.zone
      private_ip = google_compute_instance.app_vm.network_interface[0].network_ip
    }
    vm_b = {
      name       = google_compute_instance.test_vm_b.name
      zone       = google_compute_instance.test_vm_b.zone
      private_ip = google_compute_instance.test_vm_b.network_interface[0].network_ip
    }
  }
}
