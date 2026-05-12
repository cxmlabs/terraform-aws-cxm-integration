output "external_id" {
  value       = local.iam_role_external_id
  description = "The External ID configured into the IAM role"
}

output "iam_role_name" {
  value       = local.iam_role_name
  description = "The IAM Role name"
}

output "iam_role_arn" {
  value       = local.iam_role_arn
  description = "The IAM Role ARN"
}

output "prefix" {
  value       = var.prefix
  description = "Prefix used for all resource names."
}

output "cxm_aws_account_id" {
  value       = var.cxm_aws_account_id
  description = "CXM AWS account ID trusted by the IAM role."
}
