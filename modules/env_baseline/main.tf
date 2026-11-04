# One environment's folder and its IAM. Called by 2-env/envs/<env>.

resource "google_folder" "env" {
  display_name        = var.folder_name
  parent              = var.parent
  deletion_protection = true
}

locals {
  bindings = merge([
    for member, roles in var.folder_roles : { for role in roles : "${member} ${role}" => { member = member, role = role } }
  ]...)
}

# Additive: bindings made outside Terraform are left alone.
resource "google_folder_iam_member" "env" {
  for_each = local.bindings
  folder   = google_folder.env.name
  role     = each.value.role
  member   = each.value.member
}
