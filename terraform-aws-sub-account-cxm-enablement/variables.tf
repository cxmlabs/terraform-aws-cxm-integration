
# Required
variable "cxm_aws_account_id" {
  type        = string
  description = "The Cloud ex Machina AWS account ID. Provided by CXM."
}

variable "cxm_external_id" {
  type        = string
  description = "External ID for the CXM trust relationship. Provided by CXM."
}

variable "cxm_admin_role_arn" {
  type        = string
  description = "ARN of the organization-crawler role in the management account. This role is allowed to assume the asset-crawler role created by this module."
}

# Optional
variable "prefix" {
  type        = string
  default     = "cxm"
  description = "Prefix for all resource names created by this module."
}

variable "role_suffix" {
  type        = string
  default     = ""
  description = "Suffix appended to IAM role names (e.g. '-prod' produces 'cxm-asset-crawler-prod')."
}

variable "enable_scheduling" {
  type        = bool
  default     = false
  description = "Enable scheduling and scaling permissions for FinOps cost optimization (stop/start EC2, RDS, scale ECS, ASG, etc.)."
}

variable "permission_boundary_arn" {
  type        = string
  default     = null
  description = "Optional ARN of a permissions boundary policy to attach to created IAM roles."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply to all resources created by this module."
}
