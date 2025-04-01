locals {
  iam_role_arn         = module.cxm_cfg_iam_role.created ? module.cxm_cfg_iam_role.arn : var.use_existing_iam_role
  iam_role_name        = module.cxm_cfg_iam_role.created ? module.cxm_cfg_iam_role.name : "${var.prefix}-${var.iam_role_name}"
  iam_role_external_id = module.cxm_cfg_iam_role.created ? module.cxm_cfg_iam_role.external_id : var.cxm_external_id
  cxm_organizations_policy_name = (
    var.cxm_read_only_policy_name != null ? var.cxm_read_only_policy_name : "${var.prefix}-crawler-ro-${random_id.uniq.hex}"
  )
}

resource "random_id" "uniq" {
  byte_length = 4
}

data "aws_region" "current" {}

################################################################
#
# Default IAM Role to crawl the organization
#
################################################################
module "cxm_cfg_iam_role" {
  depends_on              = [aws_cloudwatch_event_rule.cxm_organization_access_event_rule]
  source                  = "../terraform-aws-iam-role"
  dry_run                 = var.use_existing_iam_role != null ? true : false
  iam_role_name           = "${var.prefix}-${var.iam_role_name}"
  external_id             = var.use_existing_iam_role != null ? "" : var.cxm_external_id
  permission_boundary_arn = var.permission_boundary_arn
  cxm_aws_account_id      = var.cxm_aws_account_id
  tags                    = var.tags
}

resource "aws_iam_role_policy_attachment" "organization_read_only_access_policy_attachment" {
  count      = var.use_existing_iam_role_policy ? 0 : 1
  role       = local.iam_role_name
  policy_arn = "arn:aws:iam::aws:policy/AWSOrganizationsReadOnlyAccess"
  depends_on = [module.cxm_cfg_iam_role]
}

################################################################
#
# Required to also crawl the AWS Organization Assets
#
################################################################
data "aws_iam_policy_document" "cxm_organization_read_only_policy" {
  count   = var.use_existing_iam_role_policy ? 0 : 1
  version = "2012-10-17"

  statement {
    # Describing CUR Data Exports / Reports to decide on which one to use
    sid = "DescribeReportDefinitions"
    actions = [
      "cur:DescribeReportDefinitions",
      "cur:ListTagsForResource",
      "bcm-data-exports:List*",
      "bcm-data-exports:Get*",
      "bcm-data-exports:ListTagsForResource",
      "ce:DescribeCostCategoryDefinition",
      "ce:DescribeNotificationSubscription",
      "ce:Describe*",
      "ce:Get*",
      "ce:List*",
      "ec2:DescribeRegions"
    ]
    resources = ["*"]
  }

  statement {
    # Understand configuration and enrollment of accounts into financial optimizations
    sid = "CostOptimizationHubReadOnlyAccess"
    actions = [
      "cost-optimization-hub:List*",
      "cost-optimization-hub:Get*"
    ]
    resources = ["*"]
  }

  statement {
    # Understand configuration and enrollment of accounts into financial optimizations
    sid = "CommitmentManagementPermissions"
    actions = [
      # DynamoDB Reservations
      "dynamodb:DescribeReservedCapacity",
      "dynamodb:DescribeReservedCapacityOfferings",
      # EC2 Reservations
      "ec2:DescribeReserved*",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeRegions",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeTags",
      "ec2:GetReserved*",
      # RDS Reservations
      "rds:DescribeReserved*",
      "rds:ListTagsForResource*",
      # Redshift Reservations
      "redshift:DescribeReserved*",
      "redshift:DescribeTags",
      "redshift:GetReserved*",
      # ElastiCache Reservations
      "elasticache:DescribeReserved*",
      "elasticache:ListTagsForResource",
      # ElasticSearch Reservations
      "es:DescribeReserved*",
      "es:ListTags",
      # ElasticSearch Reservations
      "es:DescribeReserved*",
      "es:ListTags",
      # Saving Plans
      "savingplans:*"
    ]
    resources = ["*"]
  }

  statement {
    # Understand users and groups in the organization
    sid = "SSOReadOnlyAccess"
    actions = [
      "sso-directory:Search*",
      "sso-directory:Describe*",
      "sso-directory:List*",
      "sso-directory:Get*",
      "sso:ListInstances",
      "identitystore:Describe*",
      "identitystore:List*",
    ]
    resources = ["*"]
  }

  statement {
    # Explicitly deny to any action that may allow to access customer data
    sid    = "ExplicitDenyToDataPlane"
    effect = "Deny"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:BatchGetItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "ec2:GetConsoleOutput",
      "ec2:GetConsoleScreenshot",
      "ecr:BatchGetImage",
      "ecr:GetAuthorizationToken",
      "ecr:GetDownloadUrlForLayer",
      "kinesis:Get*",
      "lambda:GetFunction",
      "logs:GetLogEvents",
      "sdb:Select*",
      "sqs:ReceiveMessage"
    ]
    resources = ["*"]
  }

  statement {
    # Grant Assume Role to create a role chain to read into accounts
    sid    = "AssumeRoleToMemberAccounts"
    effect = "Allow"
    actions = [
      "sts:AssumeRole"
    ]
    resources = ["arn:aws:iam::*:role/${var.prefix}-*"]
  }
}

resource "aws_iam_policy" "cxm_organization_read_only_policy" {
  count       = var.use_existing_iam_role_policy ? 0 : 1
  name        = local.cxm_organizations_policy_name
  description = "Policy enriching AWSOrganizationsReadOnlyAccess to allow Cloud ex Machina to understand the structure of the AWS Organization"
  policy      = data.aws_iam_policy_document.cxm_organization_read_only_policy[0].json
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "cxm_organization_read_only_policy_attachment" {
  count      = var.use_existing_iam_role_policy ? 0 : 1
  role       = local.iam_role_name
  policy_arn = aws_iam_policy.cxm_organization_read_only_policy[0].arn
  depends_on = [module.cxm_cfg_iam_role]
}

resource "aws_iam_role" "cxm_feedback_loop_iam_role" {
  name               = "${var.prefix}-feedback-loop-control-plane-${random_id.uniq.hex}"
  assume_role_policy = data.aws_iam_policy_document.cxm_assume_role_policy.json
  tags               = var.tags
}

################################################################
#
# Notification Infrastructure Layer
#
################################################################
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
    resources = ["arn:aws:events:*:${var.cxm_aws_account_id}:event-bus/control-plane*"]
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

################################################################
#
# Notification for changes to the AWS Organization
#
################################################################
resource "aws_cloudwatch_event_rule" "cxm_organization_changes_event_rule" {
  name        = "${var.prefix}-organization-changes-${random_id.uniq.hex}"
  description = "Notifies when changes happen to to the organization such as adding an account"

  event_pattern = jsonencode({
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      readOnly        = [false]
      eventSource     = ["organizations.amazonaws.com"]
      managementEvent = [true]
    }
  })
  tags = var.tags
}

resource "aws_cloudwatch_event_target" "cxm_organization_changes_event_target" {
  rule      = aws_cloudwatch_event_rule.cxm_organization_changes_event_rule.name
  target_id = "SendToControlPlaneBus"
  arn       = "arn:aws:events:${data.aws_region.current.name}:${var.cxm_aws_account_id}:event-bus/control-plane"
  role_arn  = aws_iam_role.cxm_feedback_loop_iam_role.arn
}

################################################################
#
# Notification that the Organization is available for crawling
#
################################################################
resource "aws_cloudwatch_event_rule" "cxm_organization_access_event_rule" {
  name        = "${var.prefix}-organization-access-${random_id.uniq.hex}"
  description = "Notifies when the IAM Role used to access the Organization is deployed"

  event_pattern = jsonencode({
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource     = ["iam.amazonaws.com"]
      eventName       = ["CreateRole", "DeleteRole"]
      readOnly        = [false]
      managementEvent = [true]
      requestParameters = {
        roleName = [
          { wildcard = "*${var.prefix}*" }
        ]
      }
    }
  })
  tags = var.tags
}

resource "aws_cloudwatch_event_target" "cxm_organization_access_event_target" {
  rule      = aws_cloudwatch_event_rule.cxm_organization_access_event_rule.name
  target_id = "SendToControlPlaneBus"
  arn       = "arn:aws:events:${data.aws_region.current.name}:${var.cxm_aws_account_id}:event-bus/control-plane"
  role_arn  = aws_iam_role.cxm_feedback_loop_iam_role.arn
}

################################################################
#
# Notifications StackSets deploying to the Organization
#
################################################################
resource "aws_cloudwatch_event_rule" "cxm_organization_cloudformation_rule" {
  name        = "${var.prefix}-organization-cloudformation-${random_id.uniq.hex}"
  description = "Notifies when the StackSet used to deploy an account is updated"

  event_pattern = jsonencode({
    resources = [
      { wildcard = "*${var.prefix}*" }
    ]
    detail-type = [
      "CloudFormation StackSet StackInstance Status Change",
      "CloudFormation StackSet Status Change"
    ]
    detail = {
      status-details = {
        status = [
          "CREATE_COMPLETE",
          "CREATE_FAILED",
          "DELETE_COMPLETE",
          "DELETE_FAILED",
          "ROLLBACK_COMPLETE",
          "ROLLBACK_FAILED",
          "UPDATE_COMPLETE",
          "UPDATE_FAILED",
          "UPDATE_ROLLBACK_COMPLETE",
          "UPDATE_ROLLBACK_FAILED"
        ]
      }
    }
  })
  tags = var.tags
}

resource "aws_cloudwatch_event_target" "cxm_organization_cloudformation_event_target" {
  rule      = aws_cloudwatch_event_rule.cxm_organization_cloudformation_rule.name
  target_id = "SendToControlPlaneBus"
  arn       = "arn:aws:events:${data.aws_region.current.name}:${var.cxm_aws_account_id}:event-bus/control-plane"
  role_arn  = aws_iam_role.cxm_feedback_loop_iam_role.arn
}
