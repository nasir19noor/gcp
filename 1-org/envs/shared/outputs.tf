output "org_id" {
  value = local.gcp.org_id
}

output "seed_project_id" {
  value = local.seed_project_id
}

output "common_folder_id" {
  value = google_folder.common.folder_id
}

output "logging_project_id" {
  value = google_project.common["logging"].project_id
}

output "billing_project_id" {
  value = google_project.common["billing"].project_id
}

output "org_audit_log_bucket" {
  value = google_logging_project_bucket_config.org_audit.id
}
