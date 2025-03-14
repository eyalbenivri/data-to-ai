resource "google_compute_network" "data-to-ai-network" {
  name = "data-to-ai-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "data-to-ai-subnetwork" {
  name   = "${local.region}-subnet"
  network = google_compute_network.data-to-ai-network.id
  region = local.region
  ip_cidr_range = "10.0.1.0/24"
}
#
# resource "google_compute_address" "static" {
#   name = "data-to-ai-default"
#   region = local.region
# }

resource "google_service_account" "notebook_service_account" {
  account_id   = "data-to-ai-sa"
  display_name = "Data-to-AI notebook Service Account"
}

# resource "google_service_account_iam_binding" "act_as_permission" {
#   service_account_id = google_service_account.notebook_service_account.id
#   role               = "roles/iam.serviceAccountUser"
#   members = [
#     "user:${var.user_account}",
#   ]
# }

resource "google_workbench_instance" "data-to-ai-workbench" {
  name     = "data-to-ai-workbench"
  location = var.zone
  timeouts {
    create = "40m"
  }
  gce_setup {
    machine_type = "e2-standard-4"
    boot_disk {
      disk_type    = "PD_BALANCED"
      disk_size_gb = "150"
    }
    data_disks {
      disk_type    = "PD_BALANCED"
      disk_size_gb = "100"
    }
    disable_public_ip = true

    shielded_instance_config {
      enable_secure_boot = true
      enable_vtpm = true
      enable_integrity_monitoring = true
    }

    service_accounts {
      email = google_service_account.notebook_service_account.email
    }
    network_interfaces {
      network = google_compute_network.data-to-ai-network.id
      subnet = google_compute_subnetwork.data-to-ai-subnetwork.id
    }

    metadata = {
      idle-timeout-seconds = "7200" # 2 hours
    }

  }

  desired_state = "ACTIVE"

  depends_on = [google_project_service.required_apis]
}
