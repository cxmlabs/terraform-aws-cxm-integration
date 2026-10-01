
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
  description = "Object key prefix the in-place query grant is narrowed to, ending at the directory that holds the per-account subtrees. A trailing `/` is added automatically. The default suits a bucket AWS writes at the root; one with a segment above (`terra-vpc/AWSLogs`, `cloudtrail/AWSLogs`) must say so, since a prefix matching no object grants nothing. Append the account id to narrow a shared bucket to one subtree."
}

variable "manage_bucket_policy" {
  type        = bool
  default     = true
  description = "Write the in-place query statements onto the bucket policy. Athena reads S3 as the account submitting the query and never as the reader role, so without these statements the integration registers tables it cannot read. Log-delivery statements survive while merge_existing_bucket_policy stays `true`. Set to `false` only when another resource already owns this bucket's policy, then merge the inplace_query_bucket_policy_statements_json output into that one."
}

variable "merge_existing_bucket_policy" {
  type        = bool
  default     = true
  description = "When manage_bucket_policy is `true`, read the bucket's current policy and merge into it instead of replacing it. Set to `false` only for a bucket that has no policy at all — the read fails otherwise."
}

variable "manage_kms_grant" {
  type        = bool
  default     = false
  description = "Set to `true` to grant each reader account kms:Decrypt on s3_bucket_kms_key_arn via a KMS grant. Additive: it never reads or replaces the key policy, so the key's existing statements (e.g. Control Tower's) are left untouched. No effect when s3_bucket_kms_key_arn is null."
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
