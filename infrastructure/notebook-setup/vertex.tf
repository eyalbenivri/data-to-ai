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

resource "google_service_account" "notebook_service_account" {
  account_id   = "data-to-ai-sa"
  display_name = "Data-to-AI notebook Service Account"
}

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
    disable_public_ip = false

    service_accounts {
      email = google_service_account.notebook_service_account.email
    }
    network_interfaces {
      network = google_compute_network.data-to-ai-network.id
      subnet = google_compute_subnetwork.data-to-ai-subnetwork.id
    }
    tags = [
      "externalssh"
    ]

    metadata = {
      idle-timeout-seconds = "7200" # 2 hours
      enable-oslogin = "TRUE"
    }

  }

  desired_state = "ACTIVE"

  depends_on = [google_project_service.required_apis, google_compute_firewall.firewall]
}

resource "google_compute_firewall" "firewall" {
  name    = "data-to-ai-workbench-externalssh-rule"
  network = google_compute_network.data-to-ai-network.id
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["externalssh"]
} # allow ssh

resource "null_resource" "remote_exec" {
  triggers = {
    instance_id = google_workbench_instance.data-to-ai-workbench.id
  }
  provisioner "remote-exec" {
    connection {
      host        = google_workbench_instance.data-to-ai-workbench.gce_setup.0.network_interfaces.0.access_configs.0.external_ip
      type        = "ssh"
      # user        = "jupyter"
      timeout     = "500s"
    }
    inline = [
      "echo 'foobar'"
    ]
  }
  depends_on = [google_workbench_instance.data-to-ai-workbench, google_compute_firewall.firewall]
}

output "jupyter_notebook_url" {
  value = "https://${google_workbench_instance.data-to-ai-workbench.proxy_uri}"
}