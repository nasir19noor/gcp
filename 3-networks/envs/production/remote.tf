data "terraform_remote_state" "env" {
  backend = "gcs"
  config = {
    bucket = local.gcp.state_bucket
    prefix = "2-env/envs/${local.env}"
  }
}
