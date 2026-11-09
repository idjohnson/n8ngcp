# Enable required Google Cloud APIs
locals {
  required_services = toset([
    "compute.googleapis.com",
  ])

  db_password        = coalesce(var.db_password, random_password.db_password.result)
  n8n_encryption_key = coalesce(var.n8n_encryption_key, random_password.n8n_encryption_key.result)
}

resource "google_project_service" "required_apis" {
  for_each           = local.required_services
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# Random suffix for unique resource naming
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
  lower   = true
  numeric = true
}

# Generate a random PostgreSQL password if not provided via var.db_password
resource "random_password" "db_password" {
  length  = 24
  special = false
}

# Generate a random N8N_ENCRYPTION_KEY if not provided via var.n8n_encryption_key
resource "random_password" "n8n_encryption_key" {
  length  = 42
  special = false
}

# Allow incoming HTTP traffic to n8n port on the VM
resource "google_compute_firewall" "n8n_web" {
  name    = "allow-n8n-web-${random_string.suffix.result}"
  network = var.network

  allow {
    protocol = "tcp"
    ports    = [tostring(var.n8n_port)]
  }

  source_ranges = var.allowed_source_ranges
  target_tags   = ["n8n-server"]

  depends_on = [google_project_service.required_apis]
}

# Single Compute Engine VM hosting n8n and PostgreSQL via Docker Compose
resource "google_compute_instance" "n8n" {
  name         = coalesce(var.instance_name, "n8n-vm-${random_string.suffix.result}")
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["n8n-server"]

  boot_disk {
    initialize_params {
      image = var.boot_image
      size  = var.boot_disk_size
      type  = var.boot_disk_type
    }
  }

  network_interface {
    network = var.network

    # Assign an ephemeral public IPv4 address
    access_config {}
  }

  metadata_startup_script = <<-EOT
    #!/usr/bin/env bash
    set -euxo pipefail

    export DEBIAN_FRONTEND=noninteractive

    # Install Docker Engine and Docker Compose plugin if not already present
    if ! command -v docker >/dev/null 2>&1; then
      apt-get update -y
      apt-get install -y ca-certificates curl
      install -m 0755 -d /etc/apt/keyrings
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
      chmod a+r /etc/apt/keyrings/docker.asc
      echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "$${VERSION_CODENAME}") stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null
      apt-get update -y
      apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
      systemctl enable --now docker
    fi

    mkdir -p /opt/n8n
    cd /opt/n8n

    # Determine public base URL for n8n
    EXTERNAL_IP="$(curl -fsSL -H 'Metadata-Flavor: Google' http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip)"
    CUSTOM_WEBHOOK_URL="${var.webhook_url}"
    if [ -n "$${CUSTOM_WEBHOOK_URL}" ]; then
      PUBLIC_BASE_URL="$${CUSTOM_WEBHOOK_URL}"
    else
      PUBLIC_BASE_URL="http://$${EXTERNAL_IP}:${var.n8n_port}/"
    fi

    # Create PostgreSQL initialization script for non-root user
    cat <<'EOF' > /opt/n8n/init-data.sh
    #!/bin/bash
    set -e
    if [ -n "$${POSTGRES_NON_ROOT_USER:-}" ] && [ -n "$${POSTGRES_NON_ROOT_PASSWORD:-}" ]; then
      psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
        -c "CREATE USER \"$${POSTGRES_NON_ROOT_USER}\" WITH PASSWORD '$${POSTGRES_NON_ROOT_PASSWORD}';" \
        -c "GRANT ALL PRIVILEGES ON DATABASE \"$${POSTGRES_DB}\" TO \"$${POSTGRES_NON_ROOT_USER}\";" \
        -c "GRANT ALL ON SCHEMA public TO \"$${POSTGRES_NON_ROOT_USER}\";"
    else
      echo "SETUP INFO: No Environment variables given!"
    fi
    EOF
    chmod +x /opt/n8n/init-data.sh

    # Create .env file for Docker Compose
    cat <<EOF > /opt/n8n/.env
    POSTGRES_USER=postgres
    POSTGRES_PASSWORD=${local.db_password}
    POSTGRES_DB=${var.db_name}
    POSTGRES_NON_ROOT_USER=${var.db_user}
    POSTGRES_NON_ROOT_PASSWORD=${local.db_password}
    N8N_ENCRYPTION_KEY=${local.n8n_encryption_key}
    N8N_PORT=${var.n8n_port}
    GENERIC_TIMEZONE=${var.timezone}
    WEBHOOK_URL=$${PUBLIC_BASE_URL}
    N8N_EDITOR_BASE_URL=$${PUBLIC_BASE_URL}
    EOF
    chmod 600 /opt/n8n/.env

    # Create docker-compose.yml following official n8n PostgreSQL Docker Compose setup
    cat <<'EOF' > /opt/n8n/docker-compose.yml
    volumes:
      db_storage:
      n8n_storage:

    services:
      postgres:
        image: postgres:${var.postgres_image_tag}
        restart: always
        environment:
          - POSTGRES_USER
          - POSTGRES_PASSWORD
          - POSTGRES_DB
          - POSTGRES_NON_ROOT_USER
          - POSTGRES_NON_ROOT_PASSWORD
        volumes:
          - db_storage:/var/lib/postgresql/data
          - ./init-data.sh:/docker-entrypoint-initdb.d/init-data.sh
        healthcheck:
          test: ["CMD-SHELL", "pg_isready -h localhost -U $${POSTGRES_USER} -d $${POSTGRES_DB}"]
          interval: 5s
          timeout: 5s
          retries: 10

      n8n:
        image: ${var.container_image_name}:${var.container_image_tag}
        restart: always
        environment:
          - DB_TYPE=postgresdb
          - DB_POSTGRESDB_HOST=postgres
          - DB_POSTGRESDB_PORT=5432
          - DB_POSTGRESDB_DATABASE=$${POSTGRES_DB}
          - DB_POSTGRESDB_USER=$${POSTGRES_NON_ROOT_USER}
          - DB_POSTGRESDB_PASSWORD=$${POSTGRES_NON_ROOT_PASSWORD}
          - N8N_ENCRYPTION_KEY=$${N8N_ENCRYPTION_KEY}
          - N8N_PORT=$${N8N_PORT}
          - N8N_SECURE_COOKIE=false
          - GENERIC_TIMEZONE=$${GENERIC_TIMEZONE}
          - TZ=$${GENERIC_TIMEZONE}
          - WEBHOOK_URL=$${WEBHOOK_URL}
          - N8N_EDITOR_BASE_URL=$${N8N_EDITOR_BASE_URL}
        ports:
          - "$${N8N_PORT}:$${N8N_PORT}"
        links:
          - postgres
        volumes:
          - n8n_storage:/home/node/.n8n
        depends_on:
          postgres:
            condition: service_healthy
    EOF

    docker compose up -d
  EOT

  depends_on = [
    google_project_service.required_apis,
  ]
}
