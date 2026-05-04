
## Required
variable "cxm_aws_account_id" {
  type        = string
  description = "The Cloud ex Machina AWS account that the IAM role will grant access to. Provided by CXM."
}

variable "cxm_external_id" {
  type        = string
  description = "External ID to use in the trust relationship. Provided by CXM."
}

variable "cost_usage_report_bucket_name" {
  type        = string
  default     = null
  description = "Name of the bucket that is used to store CUR data. Required when disable_cur_analysis is false (the default)."
}

## Strongly recommended
variable "cloudtrail_bucket_name" {
  type        = string
  default     = null
  description = "Name of the bucket that is used to store Cloudtrail data. Should be set if disable_cloudtrail_analysis is not set."
}

## Feature toggles
variable "disable_asset_discovery" {
  type        = bool
  default     = false
  description = "Disable asset discovery permissions. This is strongly discouraged and will limit a lot the services provided by CXM. Enable by default."
}

variable "disable_cur_analysis" {
  type        = bool
  default     = false
  description = "Disable CUR analysis. Set to true when CUR is managed separately (e.g., lone account used only for metadata crawling). Enabled by default."
}

variable "disable_cloudtrail_analysis" {
  type        = bool
  default     = false
  description = "Disable Cloudtrail analysis permissions. This is strongly discouraged and will limit a lot the services provided by CXM. Enable by default."
}

variable "disable_flowlogs_analysis" {
  type        = bool
  default     = true
  description = "Disable VPC Flow Logs analysis. Disabled by default (opt-in). Set to false to enable."
}

variable "enable_cur_cross_account_s3_access" {
  type        = bool
  default     = false
  description = "Add a bucket policy on the CUR S3 bucket granting the CXM account direct read access for cross-account Athena/Glue queries. Opt-in. WARNING: manages the full bucket policy — customers with existing bucket policies should merge manually using the output."
}

variable "use_lone_account_instead_of_aws_organization" {
  type        = bool
  default     = false
  description = "If your AWS account is not using AWS Organization and is considered a 'lone account', set this to true. This will enable CXM on a single account. False by default."
}

variable "enable_scheduling" {
  type        = bool
  default     = false
  description = "Enable scheduling and scaling permissions for FinOps cost optimization (stop/start EC2, RDS, scale ECS, ASG, etc.). Disabled by default."
}

## Optional
variable "deployment_targets" {
  type        = set(any)
  default     = []
  description = "Add a filter, and list of Organizational Units from the Organization to only deploy to. If left blank, all organization will be crawled by default."
}

variable "permission_boundary_arn" {
  type        = string
  default     = null
  description = "Optional - ARN of the policy that is used to set the permissions boundary for the role."
}

variable "s3_kms_key_arn" {
  type        = string
  default     = null
  description = "Optional - ARN of the KMS Key that is used to encrypt CUR data"
}

variable "flowlogs_bucket_name" {
  type        = string
  default     = null
  description = "Name of the S3 bucket storing centralized VPC Flow Logs. Required when disable_flowlogs_analysis is false."
}

variable "flowlogs_kms_key_arn" {
  type        = string
  default     = null
  description = "Optional - ARN of the KMS key used to encrypt VPC Flow Logs data in S3."
}

variable "prefix" {
  type        = string
  default     = "cxm"
  description = "Optional - prefix for key constructs created by this module."
}

variable "role_suffix" {
  type        = string
  default     = null
  description = "Optional - suffix to append to roles names."
}

variable "tags" {
  type        = map(string)
  description = "A map/dictionary of Tags to be assigned to created resources"
  default     = {}
}
