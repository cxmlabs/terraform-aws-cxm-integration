# Required Variables

variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster to configure access for"
}

variable "iam_role_arn" {
  type        = string
  description = "ARN or name of the IAM role created by the CXM account enablement module (e.g., output from terraform-aws-account-enablement module)"
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

variable "user_name" {
  type        = string
  default     = null
  description = "Username to use in Kubernetes for the IAM role. Defaults to the IAM role name if not specified."
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
