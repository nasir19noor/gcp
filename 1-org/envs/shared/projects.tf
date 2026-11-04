locals {
  common_projects = {
    logging = ["logging.googleapis.com"]
    billing = ["billingbudgets.googleapis.com", "cloudbilling.googleapis.com", "monitoring.googleapis.com"]
  }
  common_apis = merge([
    for p, apis in local.common_projects : { for api in apis : "${p}/${api}" => { project = p, api = api } }
  ]...)
}

resource "random_id" "project_suffix" {
  for_each    = local.common_projects
  byte_length = 2
}

resource "google_project" "common" {
  for_each            = local.common_projects
  name                = "${local.project_prefix}-${each.key}"
  project_id          = "${local.project_prefix}-${each.key}-${random_id.project_suffix[each.key].hex}"
  folder_id           = google_folder.common.folder_id
  billing_account     = local.gcp.billing_account
  auto_create_network = false
  deletion_policy     = "PREVENT"
}

resource "google_project_service" "common" {
  for_each           = local.common_apis
  project            = google_project.common[each.value.project].project_id
  service            = each.value.api
  disable_on_destroy = false
}
