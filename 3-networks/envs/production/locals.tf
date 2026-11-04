locals {
  config = yamldecode(file("${path.module}/../../../config.yaml"))
  gcp    = local.config.gcp
  name   = local.config.naming

  # The folder name of this root is the environment: production, nonproduction.
  env     = basename(abspath(path.root))
  env_cfg = local.config.environments[local.env]

  seed_project_id = data.terraform_remote_state.env.outputs.seed_project_id
}
