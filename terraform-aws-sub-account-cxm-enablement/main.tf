################################################################
#
# Asset Crawler IAM Role
#
################################################################

resource "aws_iam_role" "asset_crawler" {
  name                 = "${var.prefix}-asset-crawler${var.role_suffix}"
  max_session_duration = 43200
  permissions_boundary = var.permission_boundary_arn

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = [
            "lambda.amazonaws.com",
            "ecs-tasks.amazonaws.com",
            "codebuild.amazonaws.com",
          ]
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.cxm_external_id
          }
        }
      },
      {
        Effect = "Allow"
        Principal = {
          AWS = var.cxm_admin_role_arn
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession",
        ]
      },
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "read_only" {
  role       = aws_iam_role.asset_crawler.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "service_quotas" {
  role       = aws_iam_role.asset_crawler.name
  policy_arn = "arn:aws:iam::aws:policy/ServiceQuotasFullAccess"
}

resource "aws_iam_role_policy_attachment" "savings_plans" {
  role       = aws_iam_role.asset_crawler.name
  policy_arn = "arn:aws:iam::aws:policy/AWSSavingsPlansFullAccess"
}
