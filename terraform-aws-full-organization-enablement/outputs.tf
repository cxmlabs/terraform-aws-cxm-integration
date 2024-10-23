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
