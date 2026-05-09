################################################################
#
# Asset Crawler IAM Role
#
################################################################

data "aws_iam_policy_document" "asset_crawler_assume_role_policy" {
  count   = var.xacct_assume_role_org_id == null ? 1 : 0
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
  }
}

data "aws_iam_policy_document" "asset_crawler_assume_role_policy_org_id" {
  count   = var.xacct_assume_role_org_id == null ? 0 : 1
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
      values   = [var.xacct_assume_role_org_id]
    }
  }
}

resource "aws_iam_role" "asset_crawler" {
  name                 = "${var.prefix}-asset-crawler${var.role_suffix}"
  max_session_duration = 43200
  permissions_boundary = var.permission_boundary_arn

  assume_role_policy = (
    var.xacct_assume_role_org_id == null ?
    data.aws_iam_policy_document.asset_crawler_assume_role_policy[0].json :
    data.aws_iam_policy_document.asset_crawler_assume_role_policy_org_id[0].json
  )

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "read_only" {
  role       = aws_iam_role.asset_crawler.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "service_quotas" {
  role = aws_iam_role.asset_crawler.name
  policy_arn = (
    var.enable_savings_modifications ?
    "arn:aws:iam::aws:policy/ServiceQuotasFullAccess" :
    "arn:aws:iam::aws:policy/ServiceQuotasReadOnlyAccess"
  )
}

resource "aws_iam_role_policy_attachment" "savings_plans" {
  role = aws_iam_role.asset_crawler.name
  policy_arn = (
    var.enable_savings_modifications ?
    "arn:aws:iam::aws:policy/AWSSavingsPlansFullAccess" :
    "arn:aws:iam::aws:policy/AWSSavingsPlansReadOnlyAccess"
  )
}
