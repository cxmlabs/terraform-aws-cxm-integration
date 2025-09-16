# AWS Configuration
variable "aws_region" {
  type        = string
  description = "AWS region where resources are deployed"
  default     = "us-west-2"
}

# CXM Configuration
variable "cxm_aws_account_id" {
  type        = string
  description = "The Cloud ex Machina AWS account ID that will be granted access"
}

variable "cxm_external_id" {
  type        = string
  description = "External ID to use in the trust relationship with CXM"
}

variable "prefix" {
  type        = string
  default     = "cxm"
  description = "Prefix to use for naming resources"
}

# Organization Configuration
variable "organizational_unit_ids" {
  type        = list(string)
  description = "List of Organizational Unit IDs where CXM roles should be deployed"
  default     = []
}

variable "deployment_regions" {
  type        = list(string)
  description = "List of AWS regions where CXM roles should be deployed"
  default     = ["us-west-2", "us-east-1"]
}

# Account IDs
variable "production_account_id" {
  type        = string
  description = "AWS Account ID for the production environment"
}

variable "staging_account_id" {
  type        = string
  description = "AWS Account ID for the staging environment"
}

# Production EKS Clusters
variable "production_cluster_names" {
  type        = list(string)
  description = "List of EKS cluster names in the production account"
  default     = []

  validation {
    condition     = length(var.production_cluster_names) > 0
    error_message = "At least one production cluster name must be provided."
  }
}

# Staging EKS Clusters
variable "staging_cluster_names" {
  type        = list(string)
  description = "List of EKS cluster names in the staging account"
  default     = []

  validation {
    condition     = length(var.staging_cluster_names) > 0
    error_message = "At least one staging cluster name must be provided."
  }
}

variable "staging_allowed_namespaces" {
  type        = list(string)
  description = "List of namespaces that CXM can access in staging clusters"
  default     = ["kube-system", "monitoring", "logging", "default"]
}

# Advanced Configuration
variable "enable_cross_account_role" {
  type        = bool
  default     = true
  description = "Whether to create a cross-account role for centralized access management"
}

variable "enable_monitoring_dashboard" {
  type        = bool
  default     = true
  description = "Whether to create CloudWatch dashboards for monitoring CXM access"
}

# Cluster-specific Configuration
variable "production_cluster_config" {
  type = map(object({
    access_scope_type       = optional(string, "cluster")
    access_scope_namespaces = optional(list(string), [])
    user_name               = optional(string, null)
    enable_access_entries   = optional(bool, true)
  }))
  description = "Per-cluster configuration for production clusters"
  default     = {}
}

variable "staging_cluster_config" {
  type = map(object({
    access_scope_type       = optional(string, "namespace")
    access_scope_namespaces = optional(list(string), ["kube-system", "monitoring"])
    user_name               = optional(string, "cxm-staging-crawler")
    enable_access_entries   = optional(bool, true)
  }))
  description = "Per-cluster configuration for staging clusters"
  default     = {}
}

# Compliance and Security
variable "require_mfa_for_cross_account_access" {
  type        = bool
  default     = false
  description = "Whether to require MFA for cross-account role assumption"
}

variable "allowed_source_ips" {
  type        = list(string)
  default     = []
  description = "List of IP addresses/CIDR blocks allowed to assume cross-account roles"
}

variable "session_duration" {
  type        = number
  default     = 3600
  description = "Maximum session duration for assumed roles (in seconds)"

  validation {
    condition     = var.session_duration >= 900 && var.session_duration <= 43200
    error_message = "Session duration must be between 900 seconds (15 minutes) and 43200 seconds (12 hours)."
  }
}

# Tagging
variable "tags" {
  type        = map(string)
  description = "A map/dictionary of Tags to be assigned to created resources"
  default = {
    Project     = "cxm-organization-enablement"
    Environment = "multi-account"
    ManagedBy   = "terraform"
  }
}
