variable "project_id" {
  description = "The Google Cloud project ID where n8n and its resources will be deployed."
  type        = string
}

variable "region" {
  description = "The Google Cloud region for Cloud Run and Cloud SQL resources."
  type        = string
  default     = "us-central1"
}

variable "backend_bucket_name" {
  description = "The GCS bucket name for storing Terraform/OpenTofu state."
  type        = string
}

variable "backend_prefix" {
  description = "The GCS prefix (path) inside the bucket for the Terraform/OpenTofu state file."
  type        = string
  default     = "terraform/n8n"
}

variable "service_name" {
  description = "The name of the Cloud Run service for n8n. If blank, a unique name will be generated."
  type        = string
  default     = ""
}

variable "service_account_name" {
  description = "The account ID for the dedicated n8n Cloud Run service account. If blank, a unique name will be generated."
  type        = string
  default     = ""
}

variable "container_image_name" {
  description = "The container image name (without tag) for n8n."
  type        = string
  default     = "docker.io/n8nio/n8n"
}

variable "container_image_tag" {
  description = "The tag of the n8n container image to deploy."
  type        = string
  default     = "latest"
}

variable "cpu" {
  description = "The number of vCPUs allocated to the n8n Cloud Run container."
  type        = string
  default     = "1"
}

variable "memory" {
  description = "The memory limit allocated to the n8n Cloud Run container (n8n docs recommend 2Gi)."
  type        = string
  default     = "2Gi"
}

variable "cpu_idle" {
  description = "Whether CPU is throttled when no requests are being processed. Set to false (--no-cpu-throttling) per n8n docs so background triggers and workflows continue running."
  type        = bool
  default     = false
}

variable "min_instance_count" {
  description = "Minimum number of Cloud Run container instances."
  type        = number
  default     = 0
}

variable "max_instance_count" {
  description = "Maximum number of Cloud Run container instances."
  type        = number
  default     = 1
}

variable "allow_unauthenticated" {
  description = "Whether to allow public unauthenticated access to the n8n Cloud Run service."
  type        = bool
  default     = true
}

variable "timezone" {
  description = "The GENERIC_TIMEZONE setting for n8n."
  type        = string
  default     = "UTC"
}

variable "webhook_url" {
  description = "Optional custom public base URL for n8n webhooks and editor (e.g., https://n8n.example.com/)."
  type        = string
  default     = ""
}

variable "db_instance_name" {
  description = "The name of the Cloud SQL PostgreSQL instance. If blank, a unique name will be generated."
  type        = string
  default     = ""
}

variable "db_version" {
  description = "The PostgreSQL version for the Cloud SQL instance."
  type        = string
  default     = "POSTGRES_16"
}

variable "db_tier" {
  description = "The machine tier for the Cloud SQL PostgreSQL instance (e.g. db-f1-micro)."
  type        = string
  default     = "db-f1-micro"
}

variable "db_edition" {
  description = "The edition for the Cloud SQL instance (ENTERPRISE or ENTERPRISE_PLUS)."
  type        = string
  default     = "ENTERPRISE"
}

variable "db_disk_size" {
  description = "The storage size in GB for the Cloud SQL instance."
  type        = number
  default     = 10
}

variable "db_disk_type" {
  description = "The disk type for the Cloud SQL instance (PD_SSD or PD_HDD)."
  type        = string
  default     = "PD_HDD"
}

variable "db_deletion_protection" {
  description = "Whether to enable Terraform deletion protection on the Cloud SQL instance."
  type        = bool
  default     = false
}

variable "db_name" {
  description = "The name of the PostgreSQL database inside the Cloud SQL instance."
  type        = string
  default     = "n8n"
}

variable "db_user" {
  description = "The PostgreSQL username for n8n."
  type        = string
  default     = "n8n-user"
}

variable "db_password" {
  description = "The PostgreSQL password for n8n. If left blank, a random password will be generated and stored in Secret Manager."
  type        = string
  default     = ""
  sensitive   = true
}

variable "n8n_encryption_key" {
  description = "The N8N_ENCRYPTION_KEY used to encrypt credentials in the database. If left blank, a random key will be generated and stored in Secret Manager."
  type        = string
  default     = ""
  sensitive   = true
}
