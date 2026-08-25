locals {
  principal = var.cxm_role_name != null ? "arn:aws:iam::${var.cxm_aws_account_id}:role/${var.cxm_role_name}" : "arn:aws:iam::${var.cxm_aws_account_id}:root"

  # One statement per reader: StringEquals with several external IDs is an OR, letting any
  # reader in with any ID. Additional readers are :root; cxm_role_name narrows the primary.
  additional_principals = [
    for reader in var.additional_cxm_readers : {
      principal   = "arn:aws:iam::${reader.account_id}:root"
      external_id = reader.external_id
    }
  ]
  trusted_readers = concat(
    [{ principal = local.principal, external_id = var.external_id }],
    local.additional_principals,
  )
}


data "aws_iam_policy_document" "cxm_assume_role_policy" {
  count   = var.dry_run ? 0 : 1
  version = "2012-10-17"

  dynamic "statement" {
    for_each = local.trusted_readers

    content {
      actions = ["sts:AssumeRole"]

      principals {
        type = "AWS"
        identifiers = [
          statement.value.principal
        ]
      }

      condition {
        test     = "StringEquals"
        variable = "sts:ExternalId"
        values   = [statement.value.external_id]
      }
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
