# Organization Enablement Outputs
output "organization_role_arn" {
  value       = module.cxm_organization_enablement.iam_role_arn
  description = "ARN of the CXM IAM role in the management account"
}

output "organization_external_id" {
  value       = module.cxm_organization_enablement.external_id
  description = "External ID configured for the organization-wide deployment"
}

# Production Cluster Outputs
output "production_clusters_enabled" {
  value = {
    for cluster_name, module_output in module.cxm_production_eks_enablement : cluster_name => {
      cluster_name                    = module_output.cluster_name
      cluster_endpoint                = module_output.cluster_endpoint
      cluster_version                 = module_output.cluster_version
      access_method                   = module_output.access_method
      cluster_supports_access_entries = module_output.cluster_supports_access_entries
      access_entry_created            = module_output.access_entry_created
      policy_association_created      = module_output.policy_association_created
      iam_role_arn                    = module_output.iam_role_arn
    }
  }
  description = "Details about CXM enablement for production clusters"
}

# Staging Cluster Outputs
output "staging_clusters_enabled" {
  value = {
    for cluster_name, module_output in module.cxm_staging_eks_enablement : cluster_name => {
      cluster_name                    = module_output.cluster_name
      cluster_endpoint                = module_output.cluster_endpoint
      cluster_version                 = module_output.cluster_version
      access_method                   = module_output.access_method
      cluster_supports_access_entries = module_output.cluster_supports_access_entries
      access_entry_created            = module_output.access_entry_created
      policy_association_created      = module_output.policy_association_created
      iam_role_arn                    = module_output.iam_role_arn
    }
  }
  description = "Details about CXM enablement for staging clusters"
}

# Cross-Account Role Outputs
output "cross_account_role_arn" {
  value       = aws_iam_role.cxm_cross_account_eks_role.arn
  description = "ARN of the cross-account role for centralized EKS access"
}

# Summary Outputs
output "summary" {
  value = {
    total_clusters_enabled = length(var.production_cluster_names) + length(var.staging_cluster_names)
    production_clusters    = length(var.production_cluster_names)
    staging_clusters       = length(var.staging_cluster_names)
    accounts_configured    = [var.production_account_id, var.staging_account_id]
    deployment_region      = var.aws_region
  }
  description = "Summary of the CXM enablement deployment"
}

# Cluster Access Information
output "cluster_access_details" {
  value = {
    production = {
      for cluster in var.production_cluster_names : cluster => {
        account_id      = var.production_account_id
        cluster_name    = cluster
        access_scope    = "cluster"
        iam_role_name   = "${var.prefix}-asset-crawler"
        iam_role_arn    = "arn:aws:iam::${var.production_account_id}:role/${var.prefix}-asset-crawler"
        kubernetes_user = "${var.prefix}-asset-crawler"
      }
    }
    staging = {
      for cluster in var.staging_cluster_names : cluster => {
        account_id         = var.staging_account_id
        cluster_name       = cluster
        access_scope       = "namespace"
        allowed_namespaces = var.staging_allowed_namespaces
        iam_role_name      = "${var.prefix}-asset-crawler"
        iam_role_arn       = "arn:aws:iam::${var.staging_account_id}:role/${var.prefix}-asset-crawler"
        kubernetes_user    = "cxm-staging-crawler"
      }
    }
  }
  description = "Detailed access information for each cluster"
}

# Monitoring Outputs
output "monitoring_dashboard_url" {
  value       = var.enable_monitoring_dashboard ? "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${var.prefix}-eks-access-monitoring" : null
  description = "URL to the CloudWatch dashboard for monitoring CXM EKS access"
}

# Verification Commands
output "verification_commands" {
  value = {
    list_production_access_entries = [
      for cluster in var.production_cluster_names :
      "aws eks list-access-entries --cluster-name ${cluster} --region ${var.aws_region} --profile production"
    ]
    list_staging_access_entries = [
      for cluster in var.staging_cluster_names :
      "aws eks list-access-entries --cluster-name ${cluster} --region ${var.aws_region} --profile staging"
    ]
    check_cross_account_role = "aws sts get-caller-identity --profile management"
    test_role_assumption = [
      "aws sts assume-role --role-arn ${aws_iam_role.cxm_cross_account_eks_role.arn} --role-session-name test-session --external-id ${var.cxm_external_id}"
    ]
  }
  description = "CLI commands to verify the CXM enablement configuration"
}
