locals {
  # feature flags
  enable_root_org_discovery     = var.disable_asset_discovery == false && var.use_lone_account_instead_of_aws_organization == false
  enable_lone_account_discovery = var.disable_asset_discovery == false && var.use_lone_account_instead_of_aws_organization == true
  enable_benchmarking_account   = var.enable_benchmarking == true
  enable_cur                    = true
  enable_cloudtrail             = !var.disable_cloudtrail_analysis
  prefix                        = var.prefix
  role_suffix                   = var.role_suffix != null ? "-${var.role_suffix}" : ""
  tags = merge({
    "provider" : "cxm",
  }, var.tags)
}
