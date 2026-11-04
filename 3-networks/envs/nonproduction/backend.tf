terraform {
  backend "gcs" {
    prefix = "3-networks/envs/nonproduction"
  }
}
