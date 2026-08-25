
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

variable "prefix" {
  type        = string
  default     = "cxm"
  description = "Prefix to use for most resources created by this module."
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

variable "inplace_query_object_prefix" {
  type        = string
  default     = "AWSLogs"
  description = "Object key prefix the in-place query grant is narrowed to. A trailing `/` is added automatically."
}

variable "manage_bucket_policy" {
  type        = bool
  default     = false
  description = "Set to `true` only for a bucket dedicated to this integration. Terraform then owns the bucket policy. Leave `false` for CloudTrail and VPC Flow Logs buckets: they carry AWS log-delivery statements, and taking ownership risks breaking log delivery. In the default mode the required statements are exposed as outputs for you to merge into your own policy."
}

variable "merge_existing_bucket_policy" {
  type        = bool
  default     = true
  description = "When manage_bucket_policy is `true`, read the bucket's current policy and merge into it instead of replacing it. Set to `false` only for a bucket that has no policy at all — the read fails otherwise."
}

variable "manage_kms_key_policy" {
  type        = bool
  default     = false
  description = "Set to `true` to let Terraform own the KMS key policy of s3_bucket_kms_key_arn. Requires existing_kms_key_policy_json. Leave `false` to take the statement from the outputs instead."
}

variable "existing_kms_key_policy_json" {
  type        = string
  default     = null
  description = "Current policy of s3_bucket_kms_key_arn, merged with the CXM decrypt statement. Required when manage_kms_key_policy is `true`: the AWS provider exposes no data source for a key policy, and replacing one without its administrative statements makes the key unmanageable."
}

variable "tags" {
  type        = map(string)
  description = "A map/dictionary of Tags to be assigned to created resources"
  default     = {}
}

variable "additional_cxm_readers" {
  type = list(object({
    account_id  = string
    external_id = string
  }))
  default     = []
  description = "Extra Cloud ex Machina accounts that read this bucket, each with its own external ID. Adds a trust statement on the reader role and an in-place query statement set on the bucket (and key) per entry, so several CXM tenants can share one bucket."
}
