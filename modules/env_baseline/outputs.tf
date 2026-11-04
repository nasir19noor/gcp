output "folder_id" {
  description = "Numeric folder ID"
  value       = google_folder.env.folder_id
}

output "folder_name" {
  description = "folders/<id>"
  value       = google_folder.env.name
}
