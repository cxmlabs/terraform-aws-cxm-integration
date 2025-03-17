locals {
  iam_role_arn         = module.cxm_cfg_iam_role.created ? module.cxm_cfg_iam_role.arn : var.iam_role_arn
  iam_role_name        = module.cxm_cfg_iam_role.created ? module.cxm_cfg_iam_role.name : "${var.prefix}-${var.iam_role_name}"
  iam_role_external_id = module.cxm_cfg_iam_role.created ? module.cxm_cfg_iam_role.external_id : var.iam_role_external_id
  cxm_s3_read_policy_name = (
    var.cxm_s3_read_policy_name != null ? var.cxm_s3_read_policy_name : "${var.prefix}-s3-ro-policy-${random_id.uniq.hex}"
  )
}

data "aws_region" "current" {}

resource "random_id" "uniq" {
  byte_length = 4
}

module "cxm_cfg_iam_role" {
  source                  = "../terraform-aws-iam-role"
  dry_run                 = var.use_existing_iam_role ? true : false
  iam_role_name           = "${var.prefix}-${var.iam_role_name}"
  external_id             = var.use_existing_iam_role ? "" : var.iam_role_external_id
  permission_boundary_arn = var.permission_boundary_arn
  cxm_aws_account_id      = var.cxm_aws_account_id
  cxm_role_name           = var.cxm_role_name
  tags                    = var.tags
}

# Cloud ex Machina custom configuration policy
data "aws_iam_policy_document" "cxm_s3_ro_policy" {
  count   = var.use_existing_iam_role_policy ? 0 : 1
  version = "2012-10-17"

  statement {
    sid       = "ListFilesInBUcket"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${var.s3_bucket_name}"]
  }

  statement {
    sid       = "ReadBucketFiles"
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${var.s3_bucket_name}/*"]
  }

  dynamic "statement" {
    for_each = var.s3_bucket_kms_key_arn != null ? [1] : []
    content {
      sid = "AccessKMSToDecryptData"
      actions = [
        "kms:Decrypt",
        "kms:GenerateDataKey"
      ]
      resources = [var.s3_bucket_kms_key_arn]
    }
  }
}

resource "aws_iam_policy" "cxm_s3_ro_policy" {
  count       = var.use_existing_iam_role_policy ? 0 : 1
  name        = local.cxm_s3_read_policy_name
  description = "A policy to allow Cloud ex Machina to read files from a specific S3 bucket"
  policy      = data.aws_iam_policy_document.cxm_s3_ro_policy[count.index].json
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "cxm_s3_ro_policy_attachment" {
  count      = var.use_existing_iam_role_policy ? 0 : 1
  role       = local.iam_role_name
  policy_arn = aws_iam_policy.cxm_s3_ro_policy[count.index].arn
  depends_on = [module.cxm_cfg_iam_role]
}

#TODO: Refactor this to have a configurable notification system
resource "aws_iam_role" "cxm_feedback_loop_iam_role" {
  name               = "${var.prefix}-feedback-loop-data-plane-${random_id.uniq.hex}"
  assume_role_policy = data.aws_iam_policy_document.cxm_assume_role_policy.json
  tags               = var.tags
}

data "aws_iam_policy_document" "cxm_assume_role_policy" {
  version = "2012-10-17"
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = [
        "events.amazonaws.com"
      ]
    }
  }
}

data "aws_iam_policy_document" "cxm_cross_account_eventbridge_put_events" {
  version = "2012-10-17"

  statement {
    sid       = "PutEventsToRemoteEventBridge"
    actions   = ["events:PutEvents"]
    resources = ["arn:aws:events:*:${var.cxm_aws_account_id}:event-bus/data-plane*"]
  }
}

resource "aws_iam_policy" "cxm_cross_account_eventbridge_policy" {
  name        = "${var.prefix}-cross-account-eventbridge-policy-${random_id.uniq.hex}"
  description = "Policy allowing EventBridge to send events cross-accounts/region"
  policy      = data.aws_iam_policy_document.cxm_cross_account_eventbridge_put_events.json
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "cxm_cross_account_eventbridge_policy_attachment" {
  role       = aws_iam_role.cxm_feedback_loop_iam_role.name
  policy_arn = aws_iam_policy.cxm_cross_account_eventbridge_policy.arn
}

resource "aws_cloudwatch_event_rule" "cxm_bucket_event_rule" {
  name        = "${var.prefix}-s3-bucket-change-notifier-${random_id.uniq.hex}"
  description = "Notifies when changes happen to files in the S3 bucket"

  event_pattern = jsonencode({
    detail = {
      bucket = {
        name = [var.s3_bucket_name]
      }
    }
    source = ["aws.s3"]
    detail-type = [
      "Object Created",
      "Object Deleted"
    ]
  })
  tags = var.tags
}

resource "aws_cloudwatch_event_target" "cxm_data_plane_bus" {
  rule      = aws_cloudwatch_event_rule.cxm_bucket_event_rule.name
  target_id = "SendToDataPlaneBus"
  arn       = "arn:aws:events:${data.aws_region.current.name}:${var.cxm_aws_account_id}:event-bus/data-plane"
  role_arn  = aws_iam_role.cxm_feedback_loop_iam_role.arn
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket      = var.s3_bucket_name
  eventbridge = true
}
