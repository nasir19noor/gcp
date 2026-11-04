terraform {
  required_version = ">= 1.9"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6"
    }
  }
}

# API calls are billed to the seed project (see 1-org). google-beta is used
# by the vpc module to make the project a Shared VPC host.
provider "google" {
  region                = local.gcp.region
  user_project_override = true
  billing_project       = local.seed_project_id

  default_labels = {
    managed-by = "terraform"
    stage      = "3-networks"
  }
}

provider "google-beta" {
  region                = local.gcp.region
  user_project_override = true
  billing_project       = local.seed_project_id

  default_labels = {
    managed-by = "terraform"
    stage      = "3-networks"
  }
}
