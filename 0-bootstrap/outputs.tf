output "project_id" {
  value = google_project.seed.project_id
}

output "folder_id" {
  value = google_folder.bootstrap.folder_id
}

output "state_bucket" {
  value = module.state_bucket.bucket_name
}

# GitHub repository variable GCP_SERVICE_ACCOUNT.
output "service_account" {
  value = google_service_account.terraform.email
}

# GitHub repository variable GCP_WORKLOAD_IDENTITY_PROVIDER.
output "workload_identity_provider" {
  value = google_iam_workload_identity_pool_provider.github.name
}
