output "cluster_name" {
  value       = var.cluster_name
  description = "Name of the EKS cluster that was configured"
}

output "cluster_endpoint" {
  value       = data.aws_eks_cluster.cluster.endpoint
  description = "Endpoint URL of the EKS cluster"
}

output "cluster_account_id" {
  value       = data.aws_eks_cluster.cluster.arn != null ? split(":", data.aws_eks_cluster.cluster.arn)[4] : null
  description = "AWS Account ID where the EKS cluster is located"
}

output "cluster_supports_access_entries" {
  value       = local.cluster_supports_access_entries
  description = "Whether the cluster natively supports access entries"
}

output "access_entry_created" {
  value       = length(aws_eks_access_entry.cxm_access_entry) > 0
  description = "Whether an access entry was created for the CXM role"
}

output "policy_association_created" {
  value       = length(aws_eks_access_policy_association.cxm_view_policy) > 0
  description = "Whether a policy association was created for the CXM role"
}

output "aws_auth_configmap_updated" {
  value       = length(kubernetes_config_map_v1_data.aws_auth) > 0
  description = "Whether the aws-auth ConfigMap was updated (for legacy clusters)"
}

output "iam_role_arn" {
  value       = data.aws_iam_role.cxm_role.arn
  description = "ARN of the IAM role that was granted access to the cluster"
}

output "access_method" {
  value       = local.cluster_supports_access_entries ? "access_entries" : "aws_auth_configmap"
  description = "Method used to grant access to the cluster (access_entries or aws_auth_configmap)"
}
