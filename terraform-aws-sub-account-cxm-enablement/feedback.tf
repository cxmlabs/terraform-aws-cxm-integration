################################################################
#
# Feedback Loop — EventBridge cross-account event forwarding
#
################################################################

resource "aws_iam_role" "feedback_loop" {
  name                 = "${var.prefix}-feedback-loop-control-plane${var.role_suffix}"
  max_session_duration = 43200

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "events.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "feedback_loop" {
  name = "cross-account-event-forwarder"
  role = aws_iam_role.feedback_loop.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "events:PutEvents"
      Resource = "arn:aws:events:*:${var.cxm_aws_account_id}:event-bus/control-plane"
    }]
  })
}

################################################################
#
# IAM Change Notifier
#
################################################################

resource "aws_cloudwatch_event_rule" "notifier" {
  name        = "${var.prefix}-iam-change-notifier${var.role_suffix}"
  description = "Notifies when CXM IAM roles change state"

  event_pattern = jsonencode({
    source      = ["aws.iam"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["iam.amazonaws.com"]
      eventName = [
        "CreateRole",
        "DeleteRole",
        "AttachRolePolicy",
        "DetachRolePolicy",
        "PutRolePolicy",
        "DeleteRolePolicy",
      ]
      readOnly = [false]
      requestParameters = {
        roleName = [{ wildcard = "*${var.prefix}*" }]
      }
    }
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "notifier" {
  rule      = aws_cloudwatch_event_rule.notifier.name
  target_id = "SendToControlPlaneBus"
  arn       = "arn:aws:events:us-east-1:${var.cxm_aws_account_id}:event-bus/control-plane"
  role_arn  = aws_iam_role.feedback_loop.arn
}
