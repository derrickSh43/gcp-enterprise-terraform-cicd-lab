variable "project_id" {
  description = "Google Cloud project ID."
  type        = string
  default     = "tester-159753"
}

variable "region" {
  description = "Google Cloud region for regional resources."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Zone for the standalone VM; must belong to region."
  type        = string
  default     = "us-central1-a"
}

variable "name_prefix" {
  description = "Optional resource name prefix, including a trailing hyphen (for example dev-)."
  type        = string
  default     = ""

  validation {
    condition     = var.name_prefix == "" || can(regex("^[a-z][a-z0-9-]*-$", var.name_prefix))
    error_message = "Use an empty prefix or lowercase letters, digits and hyphens, starting with a letter and ending with a hyphen."
  }
}

variable "credentials_file" {
  description = "Service account credentials file path relative to this module. Keep credentials out of variable values."
  type        = string
  default     = "terraform-sa-key.json"
}

variable "network_mtu" {
  description = "MTU for both VPC networks."
  type        = number
  default     = 1460
}

variable "vpc_a_cidr" {
  description = "IPv4 subnet CIDR for VPC A, also used by NCC and inter-VPC firewall rules."
  type        = string
  default     = "10.231.0.0/24"

  validation {
    condition     = can(cidrnetmask(var.vpc_a_cidr))
    error_message = "Provide a valid IPv4 CIDR."
  }
}

variable "vpc_b_cidr" {
  description = "IPv4 subnet CIDR for VPC B, also used by NCC and inter-VPC firewall rules."
  type        = string
  default     = "10.230.0.0/24"

  validation {
    condition     = can(cidrnetmask(var.vpc_b_cidr))
    error_message = "Provide a valid IPv4 CIDR."
  }
}

variable "private_ip_google_access" {
  description = "Enable Private Google Access on both subnets."
  type        = bool
  default     = true
}

variable "ncc_labels" {
  description = "Labels for the connectivity hub and spokes."
  type        = map(string)
  default     = { "label-one" = "value-one" }
}

variable "app_port" {
  description = "Application HTTP port shared by nginx, the MIG, firewall rules and health checks."
  type        = number
  default     = 8080

  validation {
    condition     = var.app_port >= 1 && var.app_port <= 65535 && floor(var.app_port) == var.app_port
    error_message = "The application port must be an integer between 1 and 65535."
  }
}

variable "public_https_source_ranges" {
  description = "Source CIDRs allowed by the public HTTPS firewall rule."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "lb_health_check_source_ranges" {
  description = "Source CIDRs for Google load balancer and health check traffic."
  type        = list(string)
  default     = ["35.191.0.0/16", "130.211.0.0/22"]
}

variable "app_machine_type" {
  description = "Machine type for application instances in the managed instance group."
  type        = string
  default     = "e2-medium"
}

variable "app_image" {
  description = "Boot image for the application instance template; startup script expects Debian with apt and nginx."
  type        = string
  default     = "debian-cloud/debian-12"
}

variable "app_disk_size_gb" {
  description = "Application instance boot disk size in GB."
  type        = number
  default     = 20
}

variable "app_instance_count" {
  description = "Target number of application instances."
  type        = number
  default     = 2

  validation {
    condition     = var.app_instance_count >= 0 && floor(var.app_instance_count) == var.app_instance_count
    error_message = "Instance count must be a nonnegative integer."
  }
}

variable "app_initial_delay_sec" {
  description = "Time to allow an application instance to start before autohealing checks."
  type        = number
  default     = 300
}

variable "health_check_path" {
  description = "HTTP path used to check application health."
  type        = string
  default     = "/"
}

variable "tls_private_key_file" {
  description = "TLS private key file path relative to this module."
  type        = string
  default     = "certs/server.key"
}

variable "tls_certificate_file" {
  description = "TLS certificate file path relative to this module."
  type        = string
  default     = "certs/server.crt"
}

variable "waf_ruleset" {
  description = "Cloud Armor preconfigured WAF ruleset to evaluate."
  type        = string
  default     = "sqli-v33-stable"
}

variable "app_service_account_id" {
  description = "Service account ID for application and standalone VM instances."
  type        = string
  default     = "app-vm-identity"
}

variable "vm_machine_type" {
  description = "Machine type for the standalone VM."
  type        = string
  default     = "n2-standard-2"
}

variable "vm_image" {
  description = "Boot image for the standalone VM."
  type        = string
  default     = "debian-cloud/debian-11"
}

variable "vm_tags" {
  description = "Network tags for the standalone VM."
  type        = list(string)
  default     = ["foo", "bar"]
}

variable "vm_disk_labels" {
  description = "Boot disk labels for the standalone VM."
  type        = map(string)
  default     = { my_label = "value" }
}

variable "vm_metadata" {
  description = "Standalone VM metadata; use vm_startup_script for the startup script."
  type        = map(string)
  default     = { foo = "bar" }
}

variable "vm_startup_script" {
  description = "Startup script for the standalone VM."
  type        = string
  default     = "echo hi > /test.txt"
}

variable "state_bucket_name" {
  description = "Globally unique name for the Terraform state bucket."
  type        = string
  default     = "tester-159753-terraform-state"
}

variable "state_bucket_location" {
  description = "Location of the state bucket; independent of the compute region."
  type        = string
  default     = "US-CENTRAL1"
}

variable "state_bucket_storage_class" {
  description = "Storage class for the state bucket."
  type        = string
  default     = "STANDARD"
}

variable "state_bucket_soft_delete_retention_seconds" {
  description = "Soft delete retention in seconds: zero to disable, or 7 to 90 days."
  type        = number
  default     = 604800

  validation {
    condition     = var.state_bucket_soft_delete_retention_seconds == 0 || (var.state_bucket_soft_delete_retention_seconds >= 604800 && var.state_bucket_soft_delete_retention_seconds <= 7776000 && floor(var.state_bucket_soft_delete_retention_seconds) == var.state_bucket_soft_delete_retention_seconds)
    error_message = "Retention must be zero or an integer between 604800 and 7776000 seconds."
  }
}

variable "state_bucket_labels" {
  description = "Labels for the Terraform state bucket."
  type        = map(string)
  default     = { purpose = "terraform-state", environment = "lab", managed_by = "terraform" }
}

variable "test_vm_b_machine_type" {
  description = "Machine type for the private NCC test VM in VPC B."
  type        = string
  default     = "e2-micro"
}

variable "iap_ssh_members" {
  description = "IAM users or groups allowed to SSH to the test VMs and view NCC routes. Empty means no new access grants."
  type        = set(string)
  default     = []

  validation {
    condition     = alltrue([for member in var.iap_ssh_members : can(regex("^(user|group):[^@ ]+@[^@ ]+$", member))])
    error_message = "Use IAM identities such as user:you@example.com or group:team@example.com."
  }
}
