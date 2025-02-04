
# ORG ASSET DISCOVERY
module "enable_root_organization" {
  source = "./terraform-aws-organization-enablement"

  count = local.enable_root_org_discovery ? 1 : 0

  providers = {
    aws = aws.root
  }

  cxm_aws_account_id      = var.cxm_aws_account_id
  cxm_external_id         = var.cxm_external_id
  iam_role_name           = "cxm-organization-crawler${local.role_suffix}"
  permission_boundary_arn = var.permission_boundary_arn
  tags                    = local.tags
}

module "enable_sub_accounts" {
  source = "./terraform-aws-full-organization-enablement"

  count = local.enable_root_org_discovery ? 1 : 0

  providers = {
    aws = aws.root
  }

  cxm_aws_account_id    = var.cxm_aws_account_id
  cxm_external_id       = var.cxm_external_id
  deployment_targets    = var.deployment_targets
  cxm_admin_role_arn    = module.enable_root_organization[0].iam_role_arn
  stack_and_role_suffix = var.role_suffix
  #tags                 = var.tags
}

# LONE ACCOUNT ASSET DISCOVERY
module "enable_lone_account" {
  source = "./terraform-aws-account-enablement"

  count = local.enable_lone_account_discovery ? 1 : 0

  providers = {
    aws = aws.root
  }

  cxm_aws_account_id      = var.cxm_aws_account_id
  cxm_external_id         = var.cxm_external_id
  iam_role_name           = "cxm-organization-crawler${local.role_suffix}"
  permission_boundary_arn = var.permission_boundary_arn
  tags                    = local.tags
}

# BENCHMARKING ACCOUNT
module "enable_benchmarking_account" {
  source = "./terraform-aws-benchmarking-account-enablement"

  count = local.enable_benchmarking_account ? 1 : 0

  providers = {
    aws = aws.benchmarking
  }

  cxm_aws_account_id      = var.cxm_aws_account_id
  cxm_external_id         = var.cxm_external_id
  iam_role_name           = "cxm-benchmark-runner${local.role_suffix}"
  permission_boundary_arn = var.permission_boundary_arn
  tags                    = local.tags
}

# COST USAGE REPORT
module "enable_cur" {
  source = "./terraform-aws-s3-bucket-read"

  count = local.enable_cur ? 1 : 0

  providers = {
    aws = aws.cur
  }

  iam_role_external_id  = var.cxm_external_id
  iam_role_name         = "cxm-cur-reader${local.role_suffix}"
  cxm_aws_account_id    = var.cxm_aws_account_id
  s3_bucket_name        = var.cost_usage_report_bucket_name
  s3_bucket_kms_key_arn = var.s3_kms_key_arn
  tags                  = local.tags
}

# CLOUDTRAIL
module "enable_cloudtrail" {
  source = "./terraform-aws-s3-bucket-read"

  count = local.enable_cloudtrail ? 1 : 0

  providers = {
    aws = aws.cloudtrail
  }

  iam_role_external_id  = var.cxm_external_id
  iam_role_name         = "cxm-cloudtrail-reader${local.role_suffix}"
  cxm_aws_account_id    = var.cxm_aws_account_id
  s3_bucket_name        = var.cloudtrail_bucket_name
  s3_bucket_kms_key_arn = var.s3_kms_key_arn
  tags                  = local.tags
}
