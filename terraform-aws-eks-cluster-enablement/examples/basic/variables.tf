variable "aws_region" {
  type        = string
  description = "AWS region where the EKS cluster is located"
  default     = "us-west-2"
}

variable "cluster_name" {
  type        = string
  description = "Name of the existing EKS cluster"
}

variable "cxm_aws_account_id" {
  type        = string
  description = "The Cloud ex Machina AWS account ID that the IAM role will grant access to"
}

variable "cxm_external_id" {
  type        = string
  description = "External ID to use in the trust relationship with CXM"
}

# Note: This module automatically detects cluster capabilities
# Legacy clusters will use aws-auth ConfigMap, modern clusters will use access entries

variable "access_scope_type" {
  type        = string
  default     = "cluster"
  description = "Type of access scope for the policy association. Valid values: 'cluster' or 'namespace'"
}

variable "access_scope_namespaces" {
  type        = list(string)
  default     = []
  description = "List of namespaces for the access scope when access_scope_type is 'namespace'"
}

variable "tags" {
  type        = map(string)
  description = "A map/dictionary of Tags to be assigned to created resources"
  default = {
    Environment = "example"
    Module      = "cxm-eks-enablement"
  }
}
