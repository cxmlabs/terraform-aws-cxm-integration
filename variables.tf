
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
  description = "Name of the bucket that is used to store CUR data. Should be set if disable_cur_analysis is not set."
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

variable "disable_cloudtrail_analysis" {
  type        = bool
  default     = false
  description = "Disable Cloudtrail analysis permissions. This is strongly discouraged and will limit a lot the services provided by CXM. Enable by default."
}

variable "use_lone_account_instead_of_aws_organization" {
  type        = bool
  default     = false
  description = "If your AWS account is not using AWS Organization and is considered a 'lone account', set this to true. This will enable CXM on a single account. False by default."
}

variable "enable_benchmarking" {
  type        = bool
  default     = false
  description = "Enabled benchmarking to authorize pro-active rightsizing optimization of resources. Disabled by default."
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

variable "tags" {
  type        = map(string)
  description = "A map/dictionary of Tags to be assigned to created resources"
  default     = {}
}
