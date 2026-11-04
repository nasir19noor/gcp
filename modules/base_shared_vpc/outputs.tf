output "project_id" {
  description = "Shared VPC host project ID"
  value       = google_project.host.project_id
}

output "network_name" {
  value = module.vpc.network_name
}

output "network_self_link" {
  value = module.vpc.network_self_link
}

output "subnets" {
  description = "Subnet self links, by name"
  value       = { (google_compute_subnetwork.base.name) = google_compute_subnetwork.base.self_link }
}

output "nat_enabled" {
  value = var.nat
}
