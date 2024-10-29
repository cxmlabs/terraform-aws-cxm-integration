variable "dry_run" {
  type        = bool
  default     = false
  description = "Setting dry_run to `true` will prevent the module from creating new resources."
}

variable "iam_role_name" {
  type        = string
  default     = ""
  description = "The IAM role name"
}

variable "cxm_aws_account_id" {
  type = string
  # Change this to a multi-tenant account for default PoVs
  default     = "596683793973"
  description = "The Cloud ex Machina AWS account that the IAM role will grant access."
}

variable "cxm_role_name" {
  type        = string
  default     = ""
  description = "Name of the IAM role in the Cloud ex Machina AWS account that will assume this execution role"
}

variable "external_id" {
  type        = string
  default     = ""
  description = "External ID provided by Cloud ex Machina to configure the role."
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
