# IAM Role outputs for EKS enablement
output "lone_account_iam_role_arn" {
  value       = length(module.enable_lone_account) > 0 ? module.enable_lone_account[0].iam_role_arn : null
  description = "ARN of the CXM IAM role for lone account deployment"
}

output "organization_iam_role_arn" {
  value       = length(module.enable_root_organization) > 0 ? module.enable_root_organization[0].iam_role_arn : null
  description = "ARN of the CXM IAM role for organization root deployment"
}

output "benchmarking_iam_role_arn" {
  value       = length(module.enable_benchmarking_account) > 0 ? module.enable_benchmarking_account[0].iam_role_arn : null
  description = "ARN of the CXM IAM role for benchmarking account"
}

# Helper output that automatically selects the appropriate role based on deployment type
output "cxm_iam_role_name" {
  value = coalesce(
    length(module.enable_lone_account) > 0 ? module.enable_lone_account[0].iam_role_name : null,
    length(module.enable_root_organization) > 0 ? module.enable_root_organization[0].iam_role_name : null
  )
  description = "Name of the CXM IAM role (automatically selects between lone account or organization deployment)"
}
