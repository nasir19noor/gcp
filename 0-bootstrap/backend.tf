# The first apply runs with local state (backend_override.tf, see README),
# because the bucket does not exist yet; the state is then migrated here.
terraform {
  backend "gcs" {
    prefix = "0-bootstrap"
  }
}
