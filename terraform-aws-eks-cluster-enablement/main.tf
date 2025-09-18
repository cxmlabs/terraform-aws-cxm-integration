locals {
  # Extract role name from ARN if provided as ARN, otherwise use as-is
  iam_role_name = can(regex("^arn:aws:iam::", var.iam_role_arn)) ? element(split("/", var.iam_role_arn), length(split("/", var.iam_role_arn)) - 1) : var.iam_role_arn

  # Check if the cluster supports access entries (EKS API version 2023-10-14 or later)
  # This is determined by checking if the cluster has the access_config block
  cluster_supports_access_entries = try(data.aws_eks_cluster.cluster.access_config[0].authentication_mode != null, false)
}

# Validation: Ensure namespaces are provided when using namespace scope
check "namespace_scope_validation" {
  assert {
    condition     = var.access_scope_type != "namespace" || length(var.access_scope_namespaces) > 0
    error_message = "When access_scope_type is 'namespace', access_scope_namespaces must contain at least one namespace."
  }
}

# Data source to get information about the EKS cluster
data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

# Data source to get the IAM role information
data "aws_iam_role" "cxm_role" {
  name = local.iam_role_name
}

# Note: For legacy clusters that don't support access entries, we recommend
# manually enabling access entries in the AWS console or via AWS CLI first,
# then using this module. Automatically updating cluster configuration via
# Terraform is complex and risky due to the many configuration options that
# need to be preserved.
#
# To manually enable access entries on a legacy cluster:
# aws eks update-cluster-config --name CLUSTER_NAME --access-config authenticationMode=API_AND_CONFIG_MAP

# Create access entry for the CXM IAM role (only if cluster supports access entries)
resource "aws_eks_access_entry" "cxm_access_entry" {
  count = local.cluster_supports_access_entries ? 1 : 0

  cluster_name      = var.cluster_name
  principal_arn     = data.aws_iam_role.cxm_role.arn
  kubernetes_groups = var.kubernetes_groups
  type              = "STANDARD"
  user_name         = data.aws_iam_role.cxm_role.name

  tags = var.tags

}

# Associate the EKS View Policy with the access entry
resource "aws_eks_access_policy_association" "cxm_view_policy" {
  count = local.cluster_supports_access_entries ? 1 : 0

  cluster_name  = var.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
  principal_arn = data.aws_iam_role.cxm_role.arn

  access_scope {
    type       = var.access_scope_type
    namespaces = var.access_scope_type == "namespace" ? var.access_scope_namespaces : null
  }

  depends_on = [aws_eks_access_entry.cxm_access_entry]
}

# For legacy clusters that don't support access entries, update the aws-auth ConfigMap
resource "kubernetes_config_map_v1_data" "aws_auth" {
  count = !local.cluster_supports_access_entries ? 1 : 0

  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = yamlencode(concat(
      try(yamldecode(data.kubernetes_config_map_v1.aws_auth[0].data["mapRoles"]), []),
      [{
        rolearn  = data.aws_iam_role.cxm_role.arn
        username = data.aws_iam_role.cxm_role.name
        groups   = var.kubernetes_groups
      }]
    ))
  }

  force = true
}

# Data source to read existing aws-auth ConfigMap for legacy clusters
data "kubernetes_config_map_v1" "aws_auth" {
  count = !local.cluster_supports_access_entries ? 1 : 0

  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }
}
