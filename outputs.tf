# Terraform outputs
output "service_name" {
  description = "The name of the deployed n8n Cloud Run service."
  value       = google_cloud_run_v2_service.n8n.name
}

output "service_url" {
  description = "The public HTTPS URL of the deployed n8n Cloud Run service."
  value       = google_cloud_run_v2_service.n8n.uri
}

output "service_account_email" {
  description = "The email of the service account running the n8n Cloud Run service."
  value       = google_service_account.n8n.email
}

output "db_instance_name" {
  description = "The name of the Cloud SQL PostgreSQL instance."
  value       = google_sql_database_instance.n8n.name
}

output "db_connection_name" {
  description = "The Cloud SQL instance connection name used by the Cloud SQL Auth Proxy."
  value       = google_sql_database_instance.n8n.connection_name
}
