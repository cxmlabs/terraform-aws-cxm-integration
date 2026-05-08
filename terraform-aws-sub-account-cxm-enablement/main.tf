################################################################
#
# Asset Crawler IAM Role
#
################################################################

data "aws_iam_policy_document" "asset_crawler_assume_role_policy" {
  version = "2012-10-17"
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = [
        "lambda.amazonaws.com",
        "ecs-tasks.amazonaws.com",
        "codebuild.amazonaws.com",
      ]
    }
    # NOTE: Does this do what they think it does? Service principals don't normally use external IDs. - dpanofsky
    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [var.cxm_external_id]
    }
  }

  statement {
    actions = [
      "sts:AssumeRole",
      "sts:TagSession",
    ]
    principals {
      type        = "AWS"
      identifiers = [var.cxm_admin_role_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalOrgID"
      values   = [data.aws_organizations_organization.current.id]
    }
  }
}

resource "aws_iam_role" "asset_crawler" {
  name                 = "${var.prefix}-asset-crawler${var.role_suffix}"
  max_session_duration = 43200
  permissions_boundary = var.permission_boundary_arn

  assume_role_policy = data.aws_iam_policy_document.asset_crawler_assume_role_policy.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "read_only" {
  role       = aws_iam_role.asset_crawler.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "service_quotas" {
  role       = aws_iam_role.asset_crawler.name
  policy_arn = var.enable_savings_modifications ? "arn:aws:iam::aws:policy/ServiceQuotasFullAccess" : "arn:aws:iam::aws:policy/ServiceQuotasReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "savings_plans" {
  role       = aws_iam_role.asset_crawler.name
  policy_arn = var.enable_savings_modifications ? "arn:aws:iam::aws:policy/AWSSavingsPlansFullAccess" : "arn:aws:iam::aws:policy/AWSSavingsPlansReadOnlyAccess"
}
