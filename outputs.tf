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
  description = "Name of the CXM IAM role (automatically selects between lone account or organization deployment)"
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

output "stackset_deployment_region" {
  value       = local.enable_root_org_discovery ? "us-east-1" : null
  description = "AWS region where StackSet instances deploy IAM roles in member accounts (hardcoded to us-east-1)"
}

output "discovered_account_ids" {
  value       = local.enable_root_org_discovery ? [for acct in data.aws_organizations_organization.org[0].non_master_accounts : acct.id if acct.status == "ACTIVE"] : []
  description = "Active sub-account IDs discovered from the organization. Use these to set up the terraform-aws-sub-account-cxm-enablement module."
}
