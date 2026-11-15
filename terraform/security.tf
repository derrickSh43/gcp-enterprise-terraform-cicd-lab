resource "google_compute_security_policy" "app_waf" {
  name = "${var.name_prefix}app-waf"

  rule {
    action   = "deny(403)"
    priority = 1000

    match {
      expr {
        expression = "evaluatePreconfiguredWaf('${var.waf_ruleset}')"
      }
    }

    description = "Block SQL injection attempts"
  }

  rule {
    action   = "allow"
    priority = 2147483647

    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
  }
}

resource "google_service_account" "app_vm_identity" {
  account_id   = var.app_service_account_id
  display_name = "Application VM identity"
}

# Keep APIs enabled if the lab is later destroyed.
resource "google_project_service" "test_access" {
  for_each = toset(["iap.googleapis.com", "oslogin.googleapis.com"])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

locals {
  test_vm_access = {
    for pair in setproduct(keys(local.test_vms), var.iap_ssh_members) :
    "${pair[0]}:${pair[1]}" => { vm = pair[0], member = pair[1] }
  }
}

# Grant SSH to the two test instances, without granting sudo access.
resource "google_compute_instance_iam_member" "test_os_login" {
  for_each = local.test_vm_access

  project       = var.project_id
  zone          = local.test_vms[each.value.vm].zone
  instance_name = local.test_vms[each.value.vm].name
  role          = "roles/compute.osLogin"
  member        = each.value.member
}

resource "google_iap_tunnel_instance_iam_member" "test_ssh" {
  for_each = local.test_vm_access

  project  = var.project_id
  zone     = local.test_vms[each.value.vm].zone
  instance = local.test_vms[each.value.vm].name
  role     = "roles/iap.tunnelResourceAccessor"
  member   = each.value.member

  condition {
    title      = "ssh-only"
    expression = "destination.port == 22"
  }

  depends_on = [google_project_service.test_access]
}

# gcloud SSH needs Compute read access even with instance-scoped OS Login.
resource "google_project_iam_member" "test_compute_viewer" {
  for_each = var.iap_ssh_members

  project = var.project_id
  role    = "roles/compute.viewer"
  member  = each.value
}

resource "google_service_account_iam_member" "test_vm_service_account_user" {
  for_each = var.iap_ssh_members

  service_account_id = google_service_account.app_vm_identity.name
  role               = "roles/iam.serviceAccountUser"
  member             = each.value
}

resource "google_project_iam_member" "test_ncc_viewer" {
  for_each = var.iap_ssh_members

  project = var.project_id
  role    = "roles/networkconnectivity.hubViewer"
  member  = each.value
}
