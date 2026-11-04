locals {
  config = yamldecode(file("${path.module}/../../../config.yaml"))
  gcp    = local.config.gcp
  name   = local.config.naming
  who    = local.config.principals
  org    = local.config.org

  org_parent      = "organizations/${local.gcp.org_id}"
  seed_project_id = data.terraform_remote_state.bootstrap.outputs.project_id

  # prj-c-<name>, plus a random suffix in the ID: project IDs are global.
  project_prefix = "${local.name.project_prefix}-${local.name.env_codes.common}"
}
