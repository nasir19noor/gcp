resource "google_folder" "common" {
  display_name        = "${local.name.folder_prefix}-common"
  parent              = local.org_parent
  deletion_protection = true
}
