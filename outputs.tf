# Terraform outputs
output "instance_name" {
  description = "The name of the deployed n8n Compute Engine VM."
  value       = google_compute_instance.n8n.name
}

output "instance_zone" {
  description = "The zone of the deployed n8n Compute Engine VM."
  value       = google_compute_instance.n8n.zone
}

output "public_ip" {
  description = "The public IPv4 address of the n8n Compute Engine VM."
  value       = google_compute_instance.n8n.network_interface[0].access_config[0].nat_ip
}

output "n8n_url" {
  description = "The public URL of the deployed n8n instance."
  value       = "http://${google_compute_instance.n8n.network_interface[0].access_config[0].nat_ip}:${var.n8n_port}"
}
