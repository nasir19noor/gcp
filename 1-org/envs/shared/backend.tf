terraform {
  backend "gcs" {
    prefix = "1-org/envs/shared"
  }
}
