locals {
  config = yamldecode(file("${path.module}/../config.yaml"))
  gcp    = local.config.gcp
  name   = local.config.naming
  gh     = local.config.github
  boot   = local.config.bootstrap

  folder_name = "${local.name.folder_prefix}-bootstrap"
  # prj-b-seed, plus a random suffix in the ID: project IDs are global.
  project_name = "${local.name.project_prefix}-${local.name.env_codes.bootstrap}-seed"
  project_id   = "${local.project_name}-${random_id.project_suffix.hex}"
}
