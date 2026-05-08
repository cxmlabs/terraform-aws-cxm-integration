################################################################
#
# Inventory Policy (asset discovery + commitment management)
# Mirrors terraform-aws-organization-enablement: base policy (describe + denies)
# plus a separate inline policy when enable_savings_modifications is true.
#
################################################################

data "aws_iam_policy_document" "inventory_policy" {
  version = "2012-10-17"

  statement {
    sid = "CommitmentMonitoringPermissions"
    actions = [
      # DynamoDB Reservations
      "dynamodb:DescribeReservedCapacity",
      "dynamodb:DescribeReservedCapacityOfferings",
      # EC2 Reservations
      "ec2:DescribeReserved*",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeAccountAttributes",
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
      # memoryDB
      "memorydb:DescribeReserved*",
      "memorydb:ListTags",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ExplicitDenyToDataPlane"
    effect = "Deny"
    actions = [
      "athena:StartCalculationExecution",
      "athena:StartQueryExecution",
      "dynamodb:GetItem",
      "dynamodb:BatchGetItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "ec2:GetConsoleOutput",
      "ec2:GetConsoleScreenshot",
      "ecr:BatchGetImage",
      "ecr:GetAuthorizationToken",
      "ecr:GetDownloadUrlForLayer",
      "ecs:RegisterTaskDefinition",
      "kinesis:GetRecords",
      "kinesis:GetShardIterator",
      "lambda:GetFunction",
      "logs:GetLogEvents",
      "sdb:Select*",
      "sqs:ReceiveMessage",
      "rds-data:*"
    ]
    resources = ["*"]
  }

  statement {
    sid       = "ExplicitDenyOnS3Files"
    effect    = "Deny"
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::*/*"]
  }
}

data "aws_iam_policy_document" "inventory_savings_modifications_policy" {
  count   = var.enable_savings_modifications ? 1 : 0
  version = "2012-10-17"

  statement {
    sid = "CommitmentManagementPermissions"
    actions = [
      "dynamodb:PurchaseReservedCapacityOfferings",
      "ec2:ModifyReservedInstances",
      "ec2:PurchaseReservedInstancesOffering",
      "ec2:CreateReservedInstancesListing",
      "ec2:CancelReservedInstancesListing",
      "ec2:GetReservedInstancesExchangeQuote",
      "ec2:AcceptReservedInstancesExchangeQuote",
      "rds:PurchaseReservedDBInstancesOffering",
      "redshift:AcceptReservedNodeExchange",
      "redshift:PurchaseReservedNodeOffering",
      "elasticache:PurchaseReservedCacheNodesOffering",
      "es:PurchaseReservedElasticsearchInstanceOffering",
      "es:PurchaseReservedInstanceOffering",
      "memorydb:PurchaseReservedNodesOffering",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "inventory" {
  name   = "${var.prefix}-asset-crawler-readonly${var.role_suffix}"
  role   = aws_iam_role.asset_crawler.id
  policy = data.aws_iam_policy_document.inventory_policy.json
}

resource "aws_iam_role_policy" "inventory_savings_modifications" {
  count = var.enable_savings_modifications ? 1 : 0

  name   = "${var.prefix}-asset-crawler-savings-modifications${var.role_suffix}"
  role   = aws_iam_role.asset_crawler.id
  policy = data.aws_iam_policy_document.inventory_savings_modifications_policy[0].json
}

################################################################
#
# Scheduling & Scaling (FinOps cost optimization)
# Only created when enable_scheduling is true
#
################################################################

data "aws_iam_policy_document" "scheduling_policy" {
  count   = var.enable_scheduling ? 1 : 0
  version = "2012-10-17"

  statement {
    sid       = "SchedulingPermissions"
    resources = ["*"]
    actions = [
      "ecs:UpdateService",
      "ec2:StartInstances",
      "ec2:StopInstances",
      "rds:StartDBInstance",
      "rds:StopDBInstance",
      "rds:StartDBCluster",
      "rds:StopDBCluster",
      "lambda:PutProvisionedConcurrencyConfig",
      "lambda:DeleteProvisionedConcurrencyConfig",
      "lambda:PutFunctionConcurrency",
      "lambda:DeleteFunctionConcurrency",
      "eks:UpdateNodegroupConfig",
      "autoscaling:UpdateAutoScalingGroup",
      "autoscaling:SetDesiredCapacity",
      "application-autoscaling:RegisterScalableTarget",
      "elasticache:ModifyReplicationGroup",
      "elasticache:ModifyCacheCluster",
      "redshift:PauseCluster",
      "redshift:ResumeCluster",
      "redshift:ResizeCluster",
      "sagemaker:UpdateEndpointWeightsAndCapacities",
    ]
  }
}

resource "aws_iam_role_policy" "scheduling" {
  count = var.enable_scheduling ? 1 : 0

  name   = "${var.prefix}-asset-crawler-scheduling${var.role_suffix}"
  role   = aws_iam_role.asset_crawler.id
  policy = data.aws_iam_policy_document.scheduling_policy[0].json
}
