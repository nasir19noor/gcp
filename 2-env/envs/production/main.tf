module "env" {
  source = "../../../modules/env_baseline"

  folder_name = "${local.name.folder_prefix}-${local.env}"
  parent      = "organizations/${local.gcp.org_id}"
  folder_roles = {
    for who, roles in local.env_cfg.folder_roles : local.who[who] => roles
  }
}
