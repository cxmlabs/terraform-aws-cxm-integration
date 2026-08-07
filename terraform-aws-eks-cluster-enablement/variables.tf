# Required Variables

variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster to configure access for"
}

variable "iam_role_arn" {
  type        = string
  description = <<-EOT
    ARN or name of the CXM IAM role to grant cluster access to. This MUST be the role that
    exists in the cluster's own AWS account - it is the identity that reaches the Kubernetes
    API server.

    Organization deployment: use the asset-crawler role deployed into every member account
    by the StackSet, i.e. the parent module's `cxm_eks_iam_role_name` output. Do NOT use the
    management account's organization crawler; that role is only the first hop of the
    assume-role chain and granting it the access entry leaves the crawler unauthorized.

    Lone-account deployment: there is a single role and it is the same one -
    `cxm_eks_iam_role_name` still resolves correctly.

    A bare name is accepted and resolved against this module's provider account. If an ARN
    is supplied its account must match that provider account, otherwise the plan fails.
  EOT
}

# Optional Variables

# Note: For legacy clusters, this module will use the aws-auth ConfigMap method.
# To use access entries on legacy clusters, manually enable them first:
# aws eks update-cluster-config --name CLUSTER_NAME --access-config authenticationMode=API_AND_CONFIG_MAP

variable "kubernetes_groups" {
  type        = list(string)
  default     = []
  description = "List of Kubernetes groups to assign to the IAM role. Only used for aws-auth ConfigMap method."
}

variable "access_scope_type" {
  type        = string
  default     = "cluster"
  description = "Type of access scope for the policy association. Valid values: 'cluster' or 'namespace'"

  validation {
    condition     = contains(["cluster", "namespace"], var.access_scope_type)
    error_message = "Access scope type must be either 'cluster' or 'namespace'."
  }
}

variable "access_scope_namespaces" {
  type        = list(string)
  default     = []
  description = "List of namespaces for the access scope when access_scope_type is 'namespace'. Required when access_scope_type is 'namespace'."
}

variable "tags" {
  type        = map(string)
  description = "A map/dictionary of Tags to be assigned to created resources."
  default     = {}
}
