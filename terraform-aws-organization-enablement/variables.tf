
# Required
variable "cxm_aws_account_id" {
  type        = string
  description = "The Cloud ex Machina AWS account that the IAM role will grant access from. Provided by CXM."
}

variable "cxm_external_id" {
  type        = string
  description = "External ID to use in the trust relationship. Provided by CXM."
}

# Optional
variable "use_existing_iam_role" {
  type        = string
  default     = null
  description = "Set this to some IAM role arn to force usage of an existing IAM role (default null)"
}

variable "use_existing_iam_role_policy" {
  type        = bool
  default     = false
  description = "Set this to `true` to use an existing policy on the IAM role."
}

variable "iam_role_name" {
  type        = string
  default     = "cxm-organization-crawler"
  description = "The IAM role name. Required to match with iam_role_arn if use_existing_iam_role is set to `true`."
}

variable "permission_boundary_arn" {
  type        = string
  default     = null
  description = "Optional - ARN of the policy that is used to set the permissions boundary for the role."
}


variable "cxm_read_only_policy_name" {
  type        = string
  default     = null
  description = "The name of the policy used to authorize Cloud ex Machina to read the AWS Organizations API.  Defaults to cxm-organizations-ro-$${random_id.uniq.hex} when empty."
}

variable "tags" {
  type        = map(string)
  description = "A map of K:V pairs to use as tags on all resources."
  default     = {}
}
