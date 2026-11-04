terraform {
  backend "gcs" {
    prefix = "2-env/envs/nonproduction"
  }
}
