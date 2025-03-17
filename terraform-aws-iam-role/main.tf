locals {
  principal = var.cxm_role_name != null ? "arn:aws:iam::${var.cxm_aws_account_id}:role/${var.cxm_role_name}" : "arn:aws:iam::${var.cxm_aws_account_id}:root"
}


data "aws_iam_policy_document" "cxm_assume_role_policy" {
  count   = var.dry_run ? 0 : 1
  version = "2012-10-17"
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type = "AWS"
      identifiers = [
        local.principal
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [var.external_id]
    }
  }
}

resource "aws_iam_role" "cxm_iam_role" {
  count                = var.dry_run ? 0 : 1
  name                 = var.iam_role_name
  assume_role_policy   = data.aws_iam_policy_document.cxm_assume_role_policy[count.index].json
  permissions_boundary = var.permission_boundary_arn
  tags                 = var.tags
  max_session_duration = 12 * 3600
}
