################################################################
#
# Inventory Policy (asset discovery + commitment management)
#
################################################################

resource "aws_iam_role_policy" "inventory" {
  name = "${var.prefix}-asset-crawler-readonly${var.role_suffix}"
  role = aws_iam_role.asset_crawler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "CommitmentManagementPermissions"
        Effect   = "Allow"
        Resource = "*"
        Action = [
          # DynamoDB Reservations
          "dynamodb:DescribeReservedCapacity",
          "dynamodb:DescribeReservedCapacityOfferings",
          # Removed read/write access - dpanofsky
          # "dynamodb:PurchaseReservedCapacityOfferings",
          # EC2 Reservations
          "ec2:DescribeReserved*",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeAccountAttributes",
          "ec2:DescribeRegions",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeTags",
          "ec2:GetReserved*",
          # Removed read/write access - dpanofsky
          # "ec2:ModifyReservedInstances",
          # "ec2:PurchaseReservedInstancesOffering",
          # "ec2:CreateReservedInstancesListing",
          # "ec2:CancelReservedInstancesListing",
          # "ec2:GetReservedInstancesExchangeQuote",
          # "ec2:AcceptReservedInstancesExchangeQuote",
          # RDS Reservations
          "rds:DescribeReserved*",
          "rds:ListTagsForResource*",
          # Removed read/write access - dpanofsky
          # "rds:PurchaseReservedDBInstancesOffering",
          # Redshift Reservations
          "redshift:DescribeReserved*",
          "redshift:DescribeTags",
          "redshift:GetReserved*",
          # Removed read/write access - dpanofsky
          # "redshift:AcceptReservedNodeExchange",
          # "redshift:PurchaseReservedNodeOffering",
          # ElastiCache Reservations
          "elasticache:DescribeReserved*",
          "elasticache:ListTagsForResource",
          # Removed read/write access - dpanofsky
          # "elasticache:PurchaseReservedCacheNodesOffering",
          # ElasticSearch Reservations
          "es:DescribeReserved*",
          "es:ListTags",
          # Removed read/write access - dpanofsky
          # "es:PurchaseReservedElasticsearchInstanceOffering",
          # "es:PurchaseReservedInstanceOffering",
          # memoryDB
          "memorydb:DescribeReserved*",
          "memorydb:ListTags",
          # Removed read/write access - dpanofsky
          # "memorydb:PurchaseReservedNodesOffering",
          # Saving Plans full management
          # Removed read/write access - dpanofsky
          # "savingsplans:*",
        ]
      },
      {
        Sid      = "ExplicitDenyToDataPlane"
        Effect   = "Deny"
        Resource = "*"
        Action = [
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
          "rds-data:*",
        ]
      },
      # NOTE: added this to explicitly deny read access to S3 objects following pattern from other deny lists - dpanofsky
      {
        Sid      = "ExplicitDenyOnS3Files"
        Effect   = "Deny"
        Action   = ["s3:GetObject"]
        Resource = ["arn:aws:s3:::*/*"]
      },
    ]
  })
}

################################################################
#
# Scheduling & Scaling (FinOps cost optimization)
# Only created when enable_scheduling is true
#
################################################################

resource "aws_iam_role_policy" "scheduling" {
  count = var.enable_scheduling ? 1 : 0

  name = "${var.prefix}-asset-crawler-scheduling${var.role_suffix}"
  role = aws_iam_role.asset_crawler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "SchedulingPermissions"
        Effect   = "Allow"
        Resource = "*"
        Action = [
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
      },
    ]
  })
}
