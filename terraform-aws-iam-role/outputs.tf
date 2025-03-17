output "created" {
  value       = !var.dry_run
  description = "Indicates if the resources specified in the module were created or not."
}

output "name" {
  value       = var.dry_run ? var.iam_role_name : aws_iam_role.cxm_iam_role[0].name
  description = "IAM Role Name."
}

output "arn" {
  value       = var.dry_run ? null : aws_iam_role.cxm_iam_role[0].arn
  description = "IAM Role ARN."
}

output "external_id" {
  value       = var.external_id
  description = "The External ID provided by Cloud ex Machina to configure the IAM role."
}
