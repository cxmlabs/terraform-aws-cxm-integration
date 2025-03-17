variable "iam_role_name" {
  type        = string
  description = "The IAM role name to create."
}

variable "external_id" {
  type        = string
  description = "External ID provided by Cloud ex Machina to configure the role."
}

variable "cxm_aws_account_id" {
  type        = string
  description = "The Cloud ex Machina AWS account that the IAM role will grant access."
}

variable "cxm_role_name" {
  type        = string
  default     = null
  description = "Name of the IAM role in the Cloud ex Machina AWS account that will assume this execution role. If null, root will be used."
}

variable "permission_boundary_arn" {
  type        = string
  default     = null
  description = "Optional - ARN of the policy that is used to set the permissions boundary for the role."
}

variable "tags" {
  type        = map(string)
  description = "A map/dictionary of Tags to be assigned to created resources."
  default     = {}
}

variable "dry_run" {
  type        = bool
  default     = false
  description = "Setting dry_run to `true` will prevent the module from creating new resources."
}
