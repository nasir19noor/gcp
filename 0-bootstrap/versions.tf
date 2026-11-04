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

# Applied with your own credentials (gcloud auth application-default login),
# not the Terraform service account it creates.
provider "google" {
  region = local.gcp.region

  default_labels = {
    managed-by = "terraform"
    stage      = "0-bootstrap"
  }
}
