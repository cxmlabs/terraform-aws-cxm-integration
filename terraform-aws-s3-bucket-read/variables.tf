
variable "use_existing_iam_role" {
  type        = bool
  default     = false
  description = "Set this to true to use an existing IAM role"
}

variable "use_existing_iam_role_policy" {
  type        = bool
  default     = false
  description = "Set this to `true` to use an existing policy on the IAM role, rather than attaching a new one"
}

variable "iam_role_arn" {
  type        = string
  default     = null
  description = "The IAM role ARN is required when setting use_existing_iam_role to `true`"
}

variable "iam_role_external_id" {
  type        = string
  default     = null
  description = "The external ID configured inside the IAM role is required when setting use_existing_iam_role to `true`"
}

variable "iam_role_name" {
  type        = string
  default     = "cxm-bucket-reader"
  description = "The IAM role name. Required to match with iam_role_arn if use_existing_iam_role is set to `true`"
}

variable "permission_boundary_arn" {
  type        = string
  default     = null
  description = "Optional - ARN of the policy that is used to set the permissions boundary for the role."
}

variable "cxm_aws_account_id" {
  type        = string
  description = "The Cloud ex Machina AWS account that the IAM role will grant access"
}

variable "cxm_role_name" {
  type        = string
  default     = null
  description = "Name of the IAM role in the Cloud ex Machina AWS account that will assume this execution role"
}

variable "s3_bucket_name" {
  type        = string
  description = "Name of the bucket that is used to store CUR data"
}

variable "s3_bucket_kms_key_arn" {
  type        = string
  default     = null
  description = "Optional - ARN of the KMS Key that is used to encrypt CUR data"
}

variable "cxm_s3_read_policy_name" {
  type        = string
  default     = null
  description = "Name of the IAM Policy to read the bucket. Defaults to cxm-s3-ro-policy-$${random_id.uniq.hex} when empty"
}

variable "tags" {
  type        = map(string)
  description = "A map/dictionary of Tags to be assigned to created resources"
  default     = {}
}
