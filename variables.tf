variable "project_id" {
  description = "The Google Cloud project ID where n8n and its resources will be deployed."
  type        = string
}

variable "region" {
  description = "The Google Cloud region for resources."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "The Google Cloud zone for the n8n Compute Engine VM."
  type        = string
  default     = "us-central1-a"
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

variable "instance_name" {
  description = "The name of the Compute Engine VM instance for n8n. If blank, a unique name will be generated."
  type        = string
  default     = ""
}

variable "machine_type" {
  description = "The Compute Engine machine type for the n8n VM."
  type        = string
  default     = "e2-small"
}

variable "boot_disk_size" {
  description = "The boot disk size in GB for the n8n VM."
  type        = number
  default     = 30
}

variable "boot_disk_type" {
  description = "The boot disk type for the n8n VM (e.g., pd-balanced, pd-ssd, pd-standard)."
  type        = string
  default     = "pd-balanced"
}

variable "boot_image" {
  description = "The boot disk OS image for the n8n VM."
  type        = string
  default     = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
}

variable "network" {
  description = "The VPC network to attach the n8n VM to."
  type        = string
  default     = "default"
}

variable "allowed_source_ranges" {
  description = "List of source IPv4 CIDR ranges allowed to access the n8n web UI port."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "n8n_port" {
  description = "The TCP port on which n8n will be exposed."
  type        = number
  default     = 5678
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

variable "postgres_image_tag" {
  description = "The tag of the official postgres Docker image to run alongside n8n."
  type        = string
  default     = "16"
}

variable "timezone" {
  description = "The GENERIC_TIMEZONE and TZ setting for n8n and PostgreSQL."
  type        = string
  default     = "UTC"
}

variable "webhook_url" {
  description = "Optional custom public base URL for n8n webhooks and editor (e.g., http://<ip>:5678/ or https://n8n.example.com/). Defaults to http://<vm-public-ip>:5678/ if left blank."
  type        = string
  default     = ""
}

variable "db_name" {
  description = "The name of the PostgreSQL database for n8n."
  type        = string
  default     = "n8n"
}

variable "db_user" {
  description = "The PostgreSQL username for n8n."
  type        = string
  default     = "n8n-user"
}

variable "db_password" {
  description = "The PostgreSQL password for n8n. If left blank, a random password will be generated."
  type        = string
  default     = ""
  sensitive   = true
}

variable "n8n_encryption_key" {
  description = "The N8N_ENCRYPTION_KEY used to encrypt credentials in the database. If left blank, a random key will be generated."
  type        = string
  default     = ""
  sensitive   = true
}
