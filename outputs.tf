# IAM Role outputs for EKS enablement
output "lone_account_iam_role_arn" {
  value       = length(module.enable_lone_account) > 0 ? module.enable_lone_account[0].iam_role_arn : null
  description = "ARN of the CXM IAM role for lone account deployment"
}

output "organization_iam_role_arn" {
  value       = length(module.enable_root_organization) > 0 ? module.enable_root_organization[0].iam_role_arn : null
  description = "ARN of the CXM IAM role for organization root deployment"
}

# Helper output that automatically selects the appropriate role based on deployment type
output "cxm_iam_role_name" {
  value = coalesce(
    length(module.enable_lone_account) > 0 ? module.enable_lone_account[0].iam_role_name : null,
    length(module.enable_root_organization) > 0 ? module.enable_root_organization[0].iam_role_name : null
  )
  description = <<-EOT
    Name of the CXM IAM role deployed in the root account (organization crawler, or the
    lone-account role). NOT the role to use for EKS cluster enablement in an Organization
    deployment - see cxm_eks_iam_role_name.
  EOT
}

# The role EKS cluster enablement must target. In an Organization deployment the crawler
# reaches the Kubernetes API as the member-account asset-crawler role (the organization
# crawler is only the jump role used for the first assume-role hop), so the EKS access
# entry must name the asset-crawler in the cluster's own account. In a lone-account
# deployment there is only one role and it is the same one.
output "cxm_eks_iam_role_name" {
  value = coalesce(
    length(module.enable_sub_accounts) > 0 ? module.enable_sub_accounts[0].iam_role_name : null,
    length(module.enable_lone_account) > 0 ? module.enable_lone_account[0].iam_role_name : null
  )
  description = "Name of the CXM IAM role to grant EKS cluster access to. Deployed in every member account (Organization) or in the single account (lone account). Pass this to terraform-aws-eks-cluster-enablement, resolved against the cluster's own account."
}

output "member_account_iam_role_name" {
  value       = length(module.enable_sub_accounts) > 0 ? module.enable_sub_accounts[0].iam_role_name : null
  description = "Name of the CXM asset-crawler IAM role deployed by the StackSet into every member account. Null for lone-account deployments."
}

# Deployment regions and accounts
output "root_account_id" {
  value       = data.aws_caller_identity.root.account_id
  description = "AWS account ID used for the root (management or lone account) deployment"
}

output "root_region" {
  value       = data.aws_region.root.name
  description = "AWS region used for the root deployment (organization crawler and EventBridge rules)"
}

output "cur_account_id" {
  value       = local.enable_cur ? data.aws_caller_identity.cur.account_id : null
  description = "AWS account ID where the CUR reader role is deployed"
}

output "cur_region" {
  value       = local.enable_cur ? data.aws_region.cur.name : null
  description = "AWS region used for the CUR deployment (must match the CUR S3 bucket region)"
}

output "cloudtrail_account_id" {
  value       = local.enable_cloudtrail ? data.aws_caller_identity.cloudtrail.account_id : null
  description = "AWS account ID where the CloudTrail reader role is deployed"
}

output "cloudtrail_region" {
  value       = local.enable_cloudtrail ? data.aws_region.cloudtrail.name : null
  description = "AWS region used for the CloudTrail deployment (must match the CloudTrail S3 bucket region)"
}

output "flowlogs_account_id" {
  value       = local.enable_flowlogs ? data.aws_caller_identity.flowlogs.account_id : null
  description = "AWS account ID where the VPC Flow Logs reader role is deployed"
}

output "flowlogs_region" {
  value       = local.enable_flowlogs ? data.aws_region.flowlogs.name : null
  description = "AWS region used for the VPC Flow Logs deployment (must match the Flow Logs S3 bucket region)"
}

output "flowlogs_iam_role_arn" {
  value       = length(module.enable_flowlogs) > 0 ? module.enable_flowlogs[0].iam_role_arn : null
  description = "ARN of the CXM IAM role for VPC Flow Logs reading"
}

# In-place query access. These buckets always carry AWS log-delivery statements, so the
# module never owns their policies: it renders the statements to merge into your own.
output "inplace_query_bucket_policy_statements" {
  value = merge(
    local.enable_cloudtrail ? { cloudtrail = module.enable_cloudtrail[0].inplace_query_bucket_policy_statements_json } : {},
    local.enable_flowlogs ? { flowlogs = module.enable_flowlogs[0].inplace_query_bucket_policy_statements_json } : {},
  )
  description = "Bucket policy statements to merge into each log bucket's existing policy so CXM can query it in place, keyed by data source."
}

output "inplace_query_kms_key_policy_statements" {
  value = {
    for source, statement in merge(
      local.enable_cloudtrail ? { cloudtrail = module.enable_cloudtrail[0].inplace_query_kms_key_policy_statement_json } : {},
      local.enable_flowlogs ? { flowlogs = module.enable_flowlogs[0].inplace_query_kms_key_policy_statement_json } : {},
    ) : source => statement if statement != null
  }
  description = "KMS key policy statements to merge into each log bucket's encryption key policy, keyed by data source. Empty when no customer managed key is configured."
}

output "stackset_deployment_region" {
  value       = local.enable_root_org_discovery ? "us-east-1" : null
  description = "AWS region where StackSet instances deploy IAM roles in member accounts (hardcoded to us-east-1)"
}

output "discovered_account_ids" {
  value       = local.enable_root_org_discovery ? [for acct in data.aws_organizations_organization.org[0].non_master_accounts : acct.id if acct.status == "ACTIVE"] : []
  description = "Active sub-account IDs discovered from the organization. Use these to set up the terraform-aws-sub-account-cxm-enablement module."
}

output "prefix" {
  value       = local.prefix
  description = "Prefix used for all resource names across modules."
}

output "role_suffix" {
  value       = local.role_suffix
  description = "Suffix appended to IAM role names."
}

output "organization_assume_role_target_pattern" {
  value       = local.enable_root_org_discovery ? "arn:aws:iam::*:role/${local.prefix}-*" : null
  description = "IAM resource pattern the org-crawler is allowed to assume into member accounts. Sub-account roles must match this pattern."
}

output "sub_account_expected_role_name" {
  value       = "${local.prefix}-asset-crawler${local.role_suffix}"
  description = "Expected IAM role name in sub-accounts. Pass this as the asset-crawler role name when running diagnostics."
}
