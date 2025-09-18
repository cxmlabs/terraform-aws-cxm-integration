# Example: Basic CXM EKS Cluster Enablement
#
# This example demonstrates how to use the terraform-aws-eks-cluster-enablement
# module with the output from the terraform-aws-account-enablement module.

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

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
}

# Configure the Kubernetes provider
# Note: This assumes you have kubectl configured to access the EKS cluster
data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = var.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

# Example: Enable CXM on the account/organization
module "cxm_integration" {
  source = "../../" # Main CXM integration module

  cxm_aws_account_id = var.cxm_aws_account_id
  cxm_external_id    = var.cxm_external_id

  # Required for most deployments
  cost_usage_report_bucket_name = var.cost_usage_report_bucket_name
  cloudtrail_bucket_name        = var.cloudtrail_bucket_name

  tags = var.tags
}

# Enable CXM access to the EKS cluster
module "cxm_eks_enablement" {
  source = "../.."

  cluster_name = var.cluster_name
  iam_role_arn = module.cxm_integration.cxm_iam_role_arn # Automatically selects the right role

  # Module automatically detects cluster capabilities and uses appropriate method

  # Configure access scope
  access_scope_type       = var.access_scope_type
  access_scope_namespaces = var.access_scope_namespaces

  tags = var.tags
}
