data "terraform_remote_state" "org" {
  backend = "gcs"
  config = {
    bucket = local.gcp.state_bucket
    prefix = "1-org/envs/shared"
  }
}
