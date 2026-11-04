terraform {
  required_version = ">= 1.9"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6"
    }
  }
}

# API calls are billed to the seed project: Org Policy, Essential Contacts and
# Budgets reject service account calls that have no quota project.
provider "google" {
  region                = local.gcp.region
  user_project_override = true
  billing_project       = local.seed_project_id

  default_labels = {
    managed-by = "terraform"
    stage      = "1-org"
  }
}
