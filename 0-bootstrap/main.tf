# Applied once, by hand, by an organization administrator. Creates what every
# other stage needs: the state bucket, the Terraform service account, and the
# Workload Identity Federation that lets GitHub Actions act as that account.

locals {
  apis = [
    "billingbudgets.googleapis.com",
    "cloudbilling.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "essentialcontacts.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "orgpolicy.googleapis.com",
    "serviceusage.googleapis.com",
    "storage.googleapis.com",
    "sts.googleapis.com",
  ]

  # What the other stages do with the service account at org level. Projects
  # it creates make it their owner, so no project roles are needed for them.
  org_roles = [
    "roles/resourcemanager.organizationAdmin", # org, folder and project IAM
    "roles/resourcemanager.folderAdmin",
    "roles/resourcemanager.projectCreator",
    "roles/orgpolicy.policyAdmin",
    "roles/logging.configWriter", # org log sink
    "roles/compute.xpnAdmin",     # Shared VPC hosts
    "roles/essentialcontacts.admin",
  ]

  billing_roles = [
    "roles/billing.user",         # link new projects to the billing account
    "roles/billing.costsManager", # budgets
  ]
}

resource "google_folder" "bootstrap" {
  display_name        = local.folder_name
  parent              = "organizations/${local.gcp.org_id}"
  deletion_protection = true
}

resource "random_id" "project_suffix" {
  byte_length = 2
}

resource "google_project" "seed" {
  name                = local.project_name
  project_id          = local.project_id
  folder_id           = google_folder.bootstrap.folder_id
  billing_account     = local.gcp.billing_account
  auto_create_network = false
  deletion_policy     = "PREVENT"
}

# Enabled here because the other stages use this project as their quota
# project (user_project_override).
resource "google_project_service" "apis" {
  for_each           = toset(local.apis)
  project            = google_project.seed.project_id
  service            = each.value
  disable_on_destroy = false
}

# --- Terraform state -----------------------------------------------------------

# Pinned to a commit of nasir19noor/terraform: a change there never reaches
# the state bucket until the ref here is bumped.
module "state_bucket" {
  source = "git::https://github.com/nasir19noor/terraform.git//gcp/modules/cloud-storage?ref=664101e308a10cba234e276e2825690a067725b5"

  project_id                  = google_project.seed.project_id
  bucket_name                 = local.gcp.state_bucket
  bucket_location             = local.gcp.region
  version_enabled             = true
  force_destroy               = false
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  depends_on = [google_project_service.apis]
}

# --- Terraform service account -------------------------------------------------

resource "google_service_account" "terraform" {
  project      = google_project.seed.project_id
  account_id   = local.boot.service_account
  display_name = "Terraform (GitHub Actions ${local.gh.repo})"
  depends_on   = [google_project_service.apis]
}

resource "google_organization_iam_member" "terraform" {
  for_each = toset(local.org_roles)
  org_id   = local.gcp.org_id
  role     = each.value
  member   = google_service_account.terraform.member
}

resource "google_billing_account_iam_member" "terraform" {
  for_each           = toset(local.billing_roles)
  billing_account_id = local.gcp.billing_account
  role               = each.value
  member             = google_service_account.terraform.member
}

resource "google_storage_bucket_iam_member" "terraform_state" {
  bucket = module.state_bucket.bucket_name
  role   = "roles/storage.objectAdmin"
  member = google_service_account.terraform.member
}

# The other stages bill their API calls to this project.
resource "google_project_iam_member" "terraform_quota" {
  project = google_project.seed.project_id
  role    = "roles/serviceusage.serviceUsageConsumer"
  member  = google_service_account.terraform.member
}

# --- Workload Identity Federation for GitHub Actions ----------------------------

resource "google_iam_workload_identity_pool" "github" {
  project                   = google_project.seed.project_id
  workload_identity_pool_id = local.boot.wif_pool
  display_name              = "GitHub Actions"
  depends_on                = [google_project_service.apis]
}

# Only tokens from this repository (by its immutable ID) on the deploy branch
# are accepted; every other repository on GitHub is rejected here.
resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = google_project.seed.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = local.boot.wif_provider
  display_name                       = "GitHub ${local.gh.repo}"

  attribute_mapping = {
    "google.subject"          = "assertion.sub"
    "attribute.repository"    = "assertion.repository"
    "attribute.repository_id" = "assertion.repository_id"
    "attribute.ref"           = "assertion.ref"
    "attribute.workflow"      = "assertion.workflow"
    "attribute.actor"         = "assertion.actor"
  }
  attribute_condition = "assertion.repository_id == '${local.gh.repo_id}' && assertion.ref == 'refs/heads/${local.gh.branch}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account_iam_member" "github" {
  service_account_id = google_service_account.terraform.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository_id/${local.gh.repo_id}"
}
