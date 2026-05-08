################################################################
#
# Inventory Policy (asset discovery + commitment management)
#
################################################################

data "aws_iam_policy_document" "inventory_policy" {
  version = "2012-10-17"

  statement {
    # Understand configuration and enrollment of accounts into financial optimizations
    sid = "CommitmentManagementPermissions"
    actions = concat([
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
      # Saving Plans full management
      # NOTE: this should be handled by the policy attachment above - dpanofsky
      # "savingsplans:*"
      ],
      var.enable_savings_modifications ? [
        # DynamoDB Reservations
        "dynamodb:PurchaseReservedCapacityOfferings",
        # EC2 Reservations
        "ec2:ModifyReservedInstances",
        "ec2:PurchaseReservedInstancesOffering",
        "ec2:CreateReservedInstancesListing",
        "ec2:CancelReservedInstancesListing",
        "ec2:GetReservedInstancesExchangeQuote",
        "ec2:AcceptReservedInstancesExchangeQuote",
        # RDS Reservations
        "rds:PurchaseReservedDBInstancesOffering",
        # Redshift Reservations
        "redshift:AcceptReservedNodeExchange",
        "redshift:PurchaseReservedNodeOffering",
        # ElastiCache Reservations
        "elasticache:PurchaseReservedCacheNodesOffering",
        # ElasticSearch Reservations
        "es:PurchaseReservedElasticsearchInstanceOffering",
        "es:PurchaseReservedInstanceOffering",
        # memoryDB
        "memorydb:PurchaseReservedNodesOffering",
        # Saving Plans full management
        # NOTE: this should be handled by the policy attachment above - dpanofsky
        # "savingsplans:*"
    ] : [])

    resources = ["*"]
  }

  statement {
    # Explicitly deny to any action that may allow to access customer data
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

  # NOTE: added this to explicitly deny read access to S3 objects following pattern from other deny lists - dpanofsky
  statement {
    # Explicitly removing read access to S3 objects
    sid     = "ExplicitDenyOnS3Files"
    effect  = "Deny"
    actions = ["s3:GetObject"]
    # NOTE: reversed the flawed logic that combined deny with not_resources - dpanofsky
    resources = ["arn:aws:s3:::*/*"]
  }
}

resource "aws_iam_role_policy" "inventory" {
  name = "${var.prefix}-asset-crawler-readonly${var.role_suffix}"
  role = aws_iam_role.asset_crawler.id

  policy = data.aws_iam_policy_document.inventory_policy.json
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
      # ECS Scaling
      "ecs:UpdateService",
      # EC2 Stop/Start
      "ec2:StartInstances",
      "ec2:StopInstances",
      # RDS Stop/Start
      "rds:StartDBInstance",
      "rds:StopDBInstance",
      "rds:StartDBCluster",
      "rds:StopDBCluster",
      # Lambda Concurrency
      "lambda:PutProvisionedConcurrencyConfig",
      "lambda:DeleteProvisionedConcurrencyConfig",
      "lambda:PutFunctionConcurrency",
      "lambda:DeleteFunctionConcurrency",
      # EKS Nodegroup Scaling
      "eks:UpdateNodegroupConfig",
      # ASG Scaling
      "autoscaling:UpdateAutoScalingGroup",
      "autoscaling:SetDesiredCapacity",
      # Application Auto Scaling
      "application-autoscaling:RegisterScalableTarget",
      # ElastiCache Scaling
      "elasticache:ModifyReplicationGroup",
      "elasticache:ModifyCacheCluster",
      # Redshift Scaling
      "redshift:PauseCluster",
      "redshift:ResumeCluster",
      "redshift:ResizeCluster",
      # SageMaker Scaling
      "sagemaker:UpdateEndpointWeightsAndCapacities",
    ]
  }
}

resource "aws_iam_role_policy" "scheduling" {
  count = var.enable_scheduling ? 1 : 0

  name = "${var.prefix}-asset-crawler-scheduling${var.role_suffix}"
  role = aws_iam_role.asset_crawler.id

  policy = data.aws_iam_policy_document.scheduling_policy[0].json
}
