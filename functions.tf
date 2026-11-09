# Enable required Google Cloud APIs
locals {
  required_Services = toset([
    "run.googleapis.com",
    "sqladmin.googleapis.com",
    "secretmanager.googleapis.com",
    "iam.googleapis.com",
  ])
}

resource "google_project_service" "required_apis" {
  for_each           = local.required_Services
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

# Create the Cloud SQL for PostgreSQL instance (Durable Mode backing store for n8n)
resource "google_sql_database_instance" "n8n" {
  name                = coalesce(var.db_instance_name, "n8n-db-${random_string.suffix.result}")
  database_version    = var.db_version
  region              = var.region
  deletion_protection = var.db_deletion_protection

  settings {
    tier              = var.db_tier
    edition           = var.db_edition
    availability_type = "ZONAL"
    disk_size         = var.db_disk_size
    disk_type         = var.db_disk_type

    ip_configuration {
      ipv4_enabled = true
    }
  }

  depends_on = [google_project_service.required_apis]
}

# Create the n8n database
resource "google_sql_database" "n8n" {
  name     = var.db_name
  instance = google_sql_database_instance.n8n.name
}

# Create the n8n database user
resource "google_sql_user" "n8n" {
  name     = var.db_user
  instance = google_sql_database_instance.n8n.name
  password = coalesce(var.db_password, random_password.db_password.result)
}

# Store the database password in Secret Manager
resource "google_secret_manager_secret" "db_password" {
  secret_id = "n8n-db-password-${random_string.suffix.result}"

  replication {
    auto {}
  }

  depends_on = [google_project_service.required_apis]
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = coalesce(var.db_password, random_password.db_password.result)
}

# Store the n8n encryption key in Secret Manager
resource "google_secret_manager_secret" "n8n_encryption_key" {
  secret_id = "n8n-encryption-key-${random_string.suffix.result}"

  replication {
    auto {}
  }

  depends_on = [google_project_service.required_apis]
}

resource "google_secret_manager_secret_version" "n8n_encryption_key" {
  secret      = google_secret_manager_secret.n8n_encryption_key.id
  secret_data = coalesce(var.n8n_encryption_key, random_password.n8n_encryption_key.result)
}

# Dedicated Service Account for the n8n Cloud Run service
resource "google_service_account" "n8n" {
  account_id   = coalesce(var.service_account_name, "n8n-sa-${random_string.suffix.result}")
  display_name = "n8n Service Account"

  depends_on = [google_project_service.required_apis]
}

# Grant the service account access to the database password secret
resource "google_secret_manager_secret_iam_member" "db_password_access" {
  secret_id = google_secret_manager_secret.db_password.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.n8n.email}"
}

# Grant the service account access to the encryption key secret
resource "google_secret_manager_secret_iam_member" "encryption_key_access" {
  secret_id = google_secret_manager_secret.n8n_encryption_key.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.n8n.email}"
}

# Grant the service account permission to connect to Cloud SQL
resource "google_project_iam_member" "cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.n8n.email}"
}

# Deploy n8n to Google Cloud Run (v2)
resource "google_cloud_run_v2_service" "n8n" {
  name                = coalesce(var.service_name, "n8n-${random_string.suffix.result}")
  location            = var.region
  ingress             = "INGRESS_TRAFFIC_ALL"
  deletion_protection = false

  template {
    service_account = google_service_account.n8n.email

    scaling {
      min_instance_count = var.min_instance_count
      max_instance_count = var.max_instance_count
    }

    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = [google_sql_database_instance.n8n.connection_name]
      }
    }

    containers {
      image   = "${var.container_image_name}:${var.container_image_tag}"
      command = ["/bin/sh"]
      args    = ["-c", "sleep 5; n8n start"]

      ports {
        container_port = 5678
      }

      resources {
        limits = {
          cpu    = var.cpu
          memory = var.memory
        }
        cpu_idle          = var.cpu_idle
        startup_cpu_boost = true
      }

      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
      }

      startup_probe {
        tcp_socket {
          port = 5678
        }
        initial_delay_seconds = 10
        period_seconds        = 10
        timeout_seconds       = 5
        failure_threshold     = 12
      }

      env {
        name  = "N8N_PORT"
        value = "5678"
      }

      env {
        name  = "N8N_PROTOCOL"
        value = "https"
      }

      env {
        name  = "N8N_USER_FOLDER"
        value = "/home/node"
      }

      env {
        name  = "GENERIC_TIMEZONE"
        value = var.timezone
      }

      env {
        name  = "QUEUE_HEALTH_CHECK_ACTIVE"
        value = "true"
      }

      env {
        name  = "DB_TYPE"
        value = "postgresdb"
      }

      env {
        name  = "DB_POSTGRESDB_DATABASE"
        value = google_sql_database.n8n.name
      }

      env {
        name  = "DB_POSTGRESDB_USER"
        value = google_sql_user.n8n.name
      }

      env {
        name  = "DB_POSTGRESDB_HOST"
        value = "/cloudsql/${google_sql_database_instance.n8n.connection_name}"
      }

      env {
        name  = "DB_POSTGRESDB_PORT"
        value = "5432"
      }

      env {
        name  = "DB_POSTGRESDB_SCHEMA"
        value = "public"
      }

      env {
        name = "DB_POSTGRESDB_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.db_password.secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "N8N_ENCRYPTION_KEY"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.n8n_encryption_key.secret_id
            version = "latest"
          }
        }
      }

      dynamic "env" {
        for_each = var.webhook_url != "" ? [var.webhook_url] : []
        content {
          name  = "WEBHOOK_URL"
          value = env.value
        }
      }

      dynamic "env" {
        for_each = var.webhook_url != "" ? [var.webhook_url] : []
        content {
          name  = "N8N_EDITOR_BASE_URL"
          value = env.value
        }
      }
    }
  }

  depends_on = [
    google_project_service.required_apis,
    google_secret_manager_secret_version.db_password,
    google_secret_manager_secret_version.n8n_encryption_key,
    google_secret_manager_secret_iam_member.db_password_access,
    google_secret_manager_secret_iam_member.encryption_key_access,
    google_project_iam_member.cloudsql_client,
  ]
}

# Allow unauthenticated public access to the Cloud Run service if enabled
resource "google_cloud_run_v2_service_iam_member" "public_access" {
  count    = var.allow_unauthenticated ? 1 : 0
  project  = google_cloud_run_v2_service.n8n.project
  location = google_cloud_run_v2_service.n8n.location
  name     = google_cloud_run_v2_service.n8n.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
