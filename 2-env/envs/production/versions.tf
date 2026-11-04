terraform {
  required_version = ">= 1.9"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0"
    }
  }
}

# API calls are billed to the seed project (see 1-org).
provider "google" {
  region                = local.gcp.region
  user_project_override = true
  billing_project       = local.seed_project_id

  default_labels = {
    managed-by = "terraform"
    stage      = "2-env"
  }
}
