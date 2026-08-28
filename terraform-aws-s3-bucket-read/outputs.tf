output "external_id" {
  value       = local.iam_role_external_id
  description = "The External ID configured into the IAM role"
}

output "iam_role_name" {
  value       = local.iam_role_name
  description = "The IAM Role name"
}

output "iam_role_arn" {
  value       = local.iam_role_arn
  description = "The IAM Role ARN"
}

output "s3_bucket_name" {
  value       = var.s3_bucket_name
  description = "Name of the S3 Bucket"
}

output "prefix" {
  value       = var.prefix
  description = "Prefix used for all resource names."
}

output "cxm_aws_account_id" {
  value       = var.cxm_aws_account_id
  description = "CXM AWS account ID trusted by the IAM role."
}

output "inplace_query_bucket_policy_statements_json" {
  value       = data.aws_iam_policy_document.cxm_inplace_bucket_statements.json
  description = "Bucket policy statements granting CXM in-place query access. Merge these into the bucket's existing policy when manage_bucket_policy is `false`."
}

output "inplace_query_object_prefix" {
  value       = local.inplace_object_prefix
  description = "Object key prefix the in-place query grant is narrowed to."
}
