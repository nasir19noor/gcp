module "shared_vpc" {
  source = "../../../modules/base_shared_vpc"

  env_code        = local.name.env_codes[local.env]
  project_prefix  = local.name.project_prefix
  folder_id       = data.terraform_remote_state.env.outputs.folder_id
  billing_account = local.gcp.billing_account
  region          = local.gcp.region
  cidr            = local.env_cfg.cidr
  subnet          = local.env_cfg.subnet
  nat             = local.env_cfg.nat
  iap_ranges      = local.config.network.iap_ranges
}
