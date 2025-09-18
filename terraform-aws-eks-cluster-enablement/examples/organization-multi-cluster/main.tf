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

# Data sources for account information
data "aws_caller_identity" "management" {
  provider = aws.management
}

data "aws_caller_identity" "production" {
  provider = aws.production
}

data "aws_caller_identity" "staging" {
  provider = aws.staging
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

# Enable CXM across the entire AWS Organization using the main integration module
module "cxm_integration" {
  source = "../../" # Main CXM integration module

  providers = {
    aws.root       = aws.management
    aws.cur        = aws.management # Adjust as needed for your CUR bucket location
    aws.cloudtrail = aws.management # Adjust as needed for your CloudTrail bucket location
  }

  cxm_aws_account_id = var.cxm_aws_account_id
  cxm_external_id    = var.cxm_external_id

  # Required for organization deployment
  cost_usage_report_bucket_name = var.cost_usage_report_bucket_name
  cloudtrail_bucket_name        = var.cloudtrail_bucket_name

  # Organization-specific configuration
  deployment_targets                           = var.deployment_targets
  use_lone_account_instead_of_aws_organization = false

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
  # Construct IAM role ARN from account ID and role name
  iam_role_arn = "arn:aws:iam::${data.aws_caller_identity.production.account_id}:role/${module.cxm_integration.cxm_iam_role_name}"

  # Production clusters get cluster-wide view access
  access_scope_type = "cluster"

  # Module automatically detects cluster capabilities

  tags = merge(var.tags, {
    Environment = "production"
    Account     = "production"
    Cluster     = each.value
  })
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
  # Construct IAM role ARN from account ID and role name
  iam_role_arn = "arn:aws:iam::${data.aws_caller_identity.staging.account_id}:role/${module.cxm_integration.cxm_iam_role_name}"

  # Staging clusters get namespace-scoped access for security
  access_scope_type       = "namespace"
  access_scope_namespaces = var.staging_allowed_namespaces

  # Module automatically detects cluster capabilities

  tags = merge(var.tags, {
    Environment = "staging"
    Account     = "staging"
    Cluster     = each.value
  })
}
