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
        # NOTE: Does this do what they think it does? Service principals don't normally use external IDs. - dpanofsky
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
        ],
        # NOTE: Adding a organization restriction to be compliant with cloud working group requirements. - dpanofsky
        Condition = {
          StringEquals = {
            "aws:PrincipalOrgID" = data.aws_organizations_organization.current.id
          }
        }
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
  role = aws_iam_role.asset_crawler.name
  # Changed to read only - dpanofsky
  # policy_arn = "arn:aws:iam::aws:policy/ServiceQuotasFullAccess"
  policy_arn = "arn:aws:iam::aws:policy/ServiceQuotasReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "savings_plans" {
  role = aws_iam_role.asset_crawler.name
  # Changed to read only - dpanofsky
  # policy_arn = "arn:aws:iam::aws:policy/AWSSavingsPlansFullAccess"
  policy_arn = "arn:aws:iam::aws:policy/AWSSavingsPlansReadOnlyAccess"
}
