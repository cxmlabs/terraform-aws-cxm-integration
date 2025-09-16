# Example: Advanced CXM EKS Cluster Enablement with Organization Setup
#
# This example demonstrates how to use the terraform-aws-eks-cluster-enablement
# module with the organization enablement modules to enable CXM access across
# multiple EKS clusters in different AWS accounts within an organization.
#
# Architecture:
# - Management Account: Runs organization enablement and deploys to member accounts
# - Production Account: Contains production EKS clusters
# - Staging Account: Contains staging/dev EKS clusters
# - Each account has CXM IAM roles deployed via StackSets
# - This configuration enables CXM access to all EKS clusters

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20"
    }
  }
}

# Configure the AWS Provider for the management account
provider "aws" {
  alias  = "management"
  region = var.aws_region
  # This should be configured with management account credentials
}

# Configure AWS providers for member accounts
provider "aws" {
  alias  = "production"
  region = var.aws_region

  assume_role {
    role_arn = "arn:aws:iam::${var.production_account_id}:role/OrganizationAccountAccessRole"
  }
}

provider "aws" {
  alias  = "staging"
  region = var.aws_region

  assume_role {
    role_arn = "arn:aws:iam::${var.staging_account_id}:role/OrganizationAccountAccessRole"
  }
}

# Data sources for EKS clusters in production account
data "aws_eks_cluster" "production_clusters" {
  provider = aws.production
  for_each = toset(var.production_cluster_names)
  name     = each.value
}

data "aws_eks_cluster_auth" "production_clusters" {
  provider = aws.production
  for_each = toset(var.production_cluster_names)
  name     = each.value
}

# Data sources for EKS clusters in staging account
data "aws_eks_cluster" "staging_clusters" {
  provider = aws.staging
  for_each = toset(var.staging_cluster_names)
  name     = each.value
}

data "aws_eks_cluster_auth" "staging_clusters" {
  provider = aws.staging
  for_each = toset(var.staging_cluster_names)
  name     = each.value
}

# Kubernetes providers for production clusters
provider "kubernetes" {
  alias = "production"

  # This is a dynamic configuration - in practice, you'd configure this per cluster
  # For multiple clusters, you might need to use a for_each approach or separate configurations
}

provider "kubernetes" {
  alias = "staging"

  # This is a dynamic configuration - in practice, you'd configure this per cluster
  # For multiple clusters, you might need to use a for_each approach or separate configurations
}

#################################################################
# Organization-wide CXM Enablement
#################################################################

# Enable CXM across the entire AWS Organization
# This deploys IAM roles to all accounts via StackSets
module "cxm_organization_enablement" {
  source = "../../terraform-aws-organization-enablement"

  providers = {
    aws = aws.management
  }

  cxm_aws_account_id = var.cxm_aws_account_id
  cxm_external_id    = var.cxm_external_id
  iam_role_name      = "asset-crawler"

  # Configure StackSet deployment
  organizational_unit_ids = var.organizational_unit_ids
  deployment_regions      = var.deployment_regions

  tags = merge(var.tags, {
    Purpose = "organization-wide-cxm-enablement"
  })
}

#################################################################
# Production Account EKS Clusters
#################################################################

# Enable CXM access to production EKS clusters
module "cxm_production_eks_enablement" {
  source = "../.."

  providers = {
    aws        = aws.production
    kubernetes = kubernetes.production
  }

  for_each = toset(var.production_cluster_names)

  cluster_name = each.value
  # Use the organization module's output to get the IAM role ARN
  # The role name follows the pattern: ${prefix}-${iam_role_name}
  iam_role_arn = "arn:aws:iam::${var.production_account_id}:role/${var.prefix}-asset-crawler"

  # Production clusters get cluster-wide view access
  access_scope_type = "cluster"

  # Module automatically detects cluster capabilities

  tags = merge(var.tags, {
    Environment = "production"
    Account     = "production"
    Cluster     = each.value
  })

  depends_on = [module.cxm_organization_enablement]
}

#################################################################
# Staging Account EKS Clusters
#################################################################

# Enable CXM access to staging EKS clusters with namespace restrictions
module "cxm_staging_eks_enablement" {
  source = "../.."

  providers = {
    aws        = aws.staging
    kubernetes = kubernetes.staging
  }

  for_each = toset(var.staging_cluster_names)

  cluster_name = each.value
  # Use the organization module's output to get the IAM role ARN
  iam_role_arn = "arn:aws:iam::${var.staging_account_id}:role/${var.prefix}-asset-crawler"

  # Staging clusters get namespace-scoped access for security
  access_scope_type       = "namespace"
  access_scope_namespaces = var.staging_allowed_namespaces

  # Custom username for staging environments
  user_name = "cxm-staging-crawler"

  # Module automatically detects cluster capabilities

  tags = merge(var.tags, {
    Environment = "staging"
    Account     = "staging"
    Cluster     = each.value
  })

  depends_on = [module.cxm_organization_enablement]
}

#################################################################
# Cross-Account Role for EKS Access (Alternative approach)
#################################################################

# Alternative: Create a cross-account role that can be assumed by CXM
# This is useful if you want centralized role management
resource "aws_iam_role" "cxm_cross_account_eks_role" {
  provider = aws.management

  name = "${var.prefix}-cross-account-eks-access"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.cxm_aws_account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.cxm_external_id
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Purpose = "cross-account-eks-access"
  })
}

# Policy allowing the cross-account role to assume member account roles
resource "aws_iam_role_policy" "cxm_cross_account_assume_policy" {
  provider = aws.management

  name = "${var.prefix}-cross-account-assume-policy"
  role = aws_iam_role.cxm_cross_account_eks_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Resource = [
          "arn:aws:iam::${var.production_account_id}:role/${var.prefix}-asset-crawler",
          "arn:aws:iam::${var.staging_account_id}:role/${var.prefix}-asset-crawler"
        ]
      }
    ]
  })
}

#################################################################
# Monitoring and Compliance
#################################################################

# CloudWatch dashboard for monitoring CXM access across clusters
resource "aws_cloudwatch_dashboard" "cxm_eks_monitoring" {
  provider = aws.management

  dashboard_name = "${var.prefix}-eks-access-monitoring"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/EKS", "cluster_failed_request_count"],
            [".", "cluster_request_total"]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "EKS API Request Metrics"
        }
      }
    ]
  })

  tags = var.tags
}
