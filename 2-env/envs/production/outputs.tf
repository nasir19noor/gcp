output "env" {
  value = local.env
}

output "env_code" {
  value = local.name.env_codes[local.env]
}

output "folder_id" {
  value = module.env.folder_id
}

output "seed_project_id" {
  value = local.seed_project_id
}
