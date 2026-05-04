output "iam_role_arn" {
  value       = aws_iam_role.asset_crawler.arn
  description = "ARN of the CXM asset-crawler IAM role created in this sub-account."
}

output "iam_role_name" {
  value       = aws_iam_role.asset_crawler.name
  description = "Name of the CXM asset-crawler IAM role."
}

output "feedback_loop_role_arn" {
  value       = aws_iam_role.feedback_loop.arn
  description = "ARN of the feedback loop IAM role for EventBridge forwarding."
}
