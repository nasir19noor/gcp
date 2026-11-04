data "terraform_remote_state" "bootstrap" {
  backend = "gcs"
  config = {
    bucket = local.gcp.state_bucket
    prefix = "0-bootstrap"
  }
}
