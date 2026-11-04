output "host_project_id" {
  value = module.shared_vpc.project_id
}

output "network_name" {
  value = module.shared_vpc.network_name
}

output "network_self_link" {
  value = module.shared_vpc.network_self_link
}

output "subnets" {
  value = module.shared_vpc.subnets
}

output "nat_enabled" {
  value = module.shared_vpc.nat_enabled
}
