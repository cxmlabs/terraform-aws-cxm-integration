output "cxm_external_id" {
  value       = var.cxm_external_id
  description = "External ID to use in the trust relationship."
}

output "cxm_aws_account_id" {
  value       = var.cxm_aws_account_id
  description = "The Cloud ex Machina AWS account that the IAM role will grant access."
}

output "prefix" {
  value       = var.prefix
  description = "Prefix to use for all resources created by this module."
}

output "iam_role_name" {
  value       = "${var.prefix}-asset-crawler${local.stack_and_role_suffix}"
  description = "CxM IAM Role deployed in all accounts"
}

output "trusted_admin_role_arn" {
  value       = var.cxm_admin_role_arn
  description = "ARN of the org-crawler role trusted to assume into sub-account asset-crawler roles."
}

output "stack_and_role_suffix" {
  value       = local.stack_and_role_suffix
  description = "Suffix appended to StackSet and IAM role names."
}

output "stackset_name" {
  value       = aws_cloudformation_stack_set.cxm_account_enablement.name
  description = "Name of the CloudFormation StackSet deploying roles to member accounts."
}
