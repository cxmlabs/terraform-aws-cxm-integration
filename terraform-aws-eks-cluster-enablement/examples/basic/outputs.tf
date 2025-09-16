output "cluster_name" {
  value       = module.cxm_eks_enablement.cluster_name
  description = "Name of the EKS cluster that was configured"
}

output "cluster_endpoint" {
  value       = module.cxm_eks_enablement.cluster_endpoint
  description = "Endpoint URL of the EKS cluster"
}

output "access_method" {
  value       = module.cxm_eks_enablement.access_method
  description = "Method used to grant access to the cluster"
}

output "iam_role_arn" {
  value       = module.cxm_eks_enablement.iam_role_arn
  description = "ARN of the IAM role that was granted access to the cluster"
}

output "cluster_supports_access_entries" {
  value       = module.cxm_eks_enablement.cluster_supports_access_entries
  description = "Whether the cluster natively supports access entries"
}

output "cxm_external_id" {
  value       = module.cxm_account_enablement.external_id
  description = "The External ID configured into the IAM role"
}
