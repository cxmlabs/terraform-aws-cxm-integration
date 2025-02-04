

variable "cxm_aws_account_id" {
  type        = string
  description = "The Cloud ex Machina AWS account that the IAM role will grant access."
}

variable "cxm_external_id" {
  type        = string
  description = "External ID to use in the trust relationship."
}

variable "cxm_admin_role_arn" {
  type        = string
  description = "The ARN of the role created in the AWS Organizations root account that will be used as a relay. "
}

variable "deployment_targets" {
  type        = set(any)
  default     = []
  description = "A list of Organizational Units from the Organization to deploy to."
}

variable "prefix" {
  type        = string
  default     = "cxm"
  description = "Prefix to use for all resources created by this module."
}

variable "stack_and_role_suffix" {
  type        = string
  default     = null
  description = "Suffix to use for the cloudformation stack."
}
