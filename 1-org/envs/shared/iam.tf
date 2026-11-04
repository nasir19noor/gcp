# Org-level roles. Additive (iam_member): bindings made outside Terraform are
# left alone. devops and developers get their roles per environment, in 2-env.

locals {
  org_roles = {
    org_admins = [
      "roles/resourcemanager.organizationAdmin",
      "roles/resourcemanager.folderAdmin",
      "roles/resourcemanager.projectCreator",
      "roles/orgpolicy.policyAdmin",
      "roles/iam.securityReviewer",
    ]
    billing_admins = [
      "roles/billing.admin",
      "roles/resourcemanager.organizationViewer",
    ]
    network_admins = [
      "roles/compute.networkAdmin",
      "roles/compute.xpnAdmin",
      "roles/compute.securityAdmin",
      "roles/resourcemanager.folderViewer",
    ]
    security_admins = [
      "roles/iam.securityReviewer",
      "roles/orgpolicy.policyViewer",
      "roles/logging.privateLogViewer",
      "roles/securitycenter.adminViewer",
      "roles/resourcemanager.folderViewer",
    ]
  }

  org_bindings = merge([
    for who, roles in local.org_roles : { for role in roles : "${who} ${role}" => { member = local.who[who], role = role } }
  ]...)
}

resource "google_organization_iam_member" "principals" {
  for_each = local.org_bindings
  org_id   = local.gcp.org_id
  role     = each.value.role
  member   = each.value.member
}
