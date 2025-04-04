
# Required
variable "cxm_aws_account_id" {
  type        = string
  description = "The Cloud ex Machina AWS account that the IAM role will grant access."
}

variable "cxm_external_id" {
  type        = string
  description = "External ID to use in the trust relationship. Required to match the existing External ID when setting use_existing_iam_role to `true`."
}

variable "iam_role_name" {
  type        = string
  description = "Name of the IAM role to set. Required to match with iam_role_arn if use_existing_iam_role is set to `true`. Will be prefixed with var.prefix."
}

# Optional
variable "prefix" {
  type        = string
  default     = "cxm"
  description = "Prefix to use to name import constructs such as IAM roles when they are not set otherwise"
}

variable "use_existing_iam_role" {
  type        = bool
  default     = false
  description = "Set to true in order to use a pre-existing IAM role. Set iam_role_arn if you do."
}

variable "use_existing_iam_role_policy" {
  type        = bool
  default     = false
  description = "Set this to `true` to use an existing policy on the IAM role, rather than attaching a new one."
}

variable "iam_role_arn" {
  type        = string
  default     = null
  description = "IAM role ARN to use. Required when setting use_existing_iam_role to `true`."
}

variable "permission_boundary_arn" {
  type        = string
  default     = null
  description = "Optional - ARN of a policy that is used to contraint permissions boundary for the role."
}


variable "cxm_read_only_policy_name" {
  type        = string
  default     = null
  description = "The name of the policy used to enrich ReadOnly to allow Cloud ex Machina to read the Control Plane.  Defaults to cxm-account-ro-$${random_id.uniq.hex} when empty."
}

variable "tags" {
  type        = map(string)
  description = "A map/dictionary of Tags to be assigned to created resources."
  default     = {}
}
