output "iam_role_arn" {
  value       = aws_iam_role.asset_crawler.arn
  description = "ARN of the CXM asset-crawler IAM role created in this sub-account."
}

output "iam_role_name" {
  value       = aws_iam_role.asset_crawler.name
  description = "Name of the CXM asset-crawler IAM role."
}

output "trusted_admin_role_arn" {
  value       = var.cxm_admin_role_arn
  description = "ARN of the admin role trusted to assume into this sub-account's asset-crawler role."
}

output "prefix" {
  value       = var.prefix
  description = "Prefix used for all resource names."
}

output "role_suffix" {
  value       = var.role_suffix
  description = "Suffix appended to IAM role names."
}

output "cxm_aws_account_id" {
  value       = var.cxm_aws_account_id
  description = "CXM AWS account ID used in trust and event forwarding policies."
}

output "feedback_loop_role_arn" {
  value       = aws_iam_role.feedback_loop.arn
  description = "ARN of the feedback loop IAM role for EventBridge forwarding."
}
