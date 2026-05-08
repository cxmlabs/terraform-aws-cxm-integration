locals {
  iam_role_arn         = module.cxm_cfg_iam_role.created ? module.cxm_cfg_iam_role.arn : var.iam_role_arn
  iam_role_name        = module.cxm_cfg_iam_role.created ? module.cxm_cfg_iam_role.name : "${var.prefix}-${var.iam_role_name}"
  iam_role_external_id = module.cxm_cfg_iam_role.created ? module.cxm_cfg_iam_role.external_id : var.cxm_external_id
  cxm_read_only_policy_name = (
    var.cxm_read_only_policy_name != null ? var.cxm_read_only_policy_name : "${var.prefix}-account-ro-${random_id.uniq.hex}"
  )
}

resource "random_id" "uniq" {
  byte_length = 4
}

module "cxm_cfg_iam_role" {
  source                  = "../terraform-aws-iam-role"
  dry_run                 = var.use_existing_iam_role ? true : false
  iam_role_name           = "${var.prefix}-${var.iam_role_name}"
  permission_boundary_arn = var.permission_boundary_arn
  cxm_aws_account_id      = var.cxm_aws_account_id
  external_id             = var.use_existing_iam_role ? "" : var.cxm_external_id
  tags                    = var.tags
}

resource "aws_iam_role_policy_attachment" "read_only_access_policy_attachment" {
  count      = var.use_existing_iam_role_policy ? 0 : 1
  role       = local.iam_role_name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
  depends_on = [module.cxm_cfg_iam_role]
}

# This is required in order to increase RI/Savings Plans quotas if need be
resource "aws_iam_role_policy_attachment" "crawler_manage_ri_quotas_policy_attachment" {
  count      = var.use_existing_iam_role_policy ? 0 : 1
  role       = local.iam_role_name
  policy_arn = var.enable_savings_modifications ? "arn:aws:iam::aws:policy/ServiceQuotasFullAccess" : "arn:aws:iam::aws:policy/ServiceQuotasReadOnlyAccess"
  depends_on = [module.cxm_cfg_iam_role]
}

# This is required in fully manage Savings Plans
resource "aws_iam_role_policy_attachment" "crawler_manage_sp_policy_attachment" {
  count      = var.use_existing_iam_role_policy ? 0 : 1
  role       = local.iam_role_name
  policy_arn = var.enable_savings_modifications ? "arn:aws:iam::aws:policy/AWSSavingsPlansFullAccess" : "arn:aws:iam::aws:policy/AWSSavingsPlansReadOnlyAccess"
  depends_on = [module.cxm_cfg_iam_role]
}

data "aws_iam_policy_document" "cxm_read_only_policy" {
  count   = var.use_existing_iam_role_policy ? 0 : 1
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
      # memoryDB
      "memorydb:DescribeReserved*",
      "es:ListTags",
      # memoryDB
      "memorydb:ListTags",
      # Saving Plans read only access
      # - savingsplans:Describe*
      # - savingsplans:List*
      # NOTE: this is handled by the `arn:aws:iam::aws:policy/AWSSavingsPlansReadOnlyAccess` policy attached above - dpanofsky
    ]
    resources = ["*"]
  }

  statement {
    # Explicitly removing read access to S3 objects
    sid     = "ExplicitDenyOnS3Files"
    effect  = "Deny"
    actions = ["s3:GetObject"]
    # NOTE: reversed the flawed logic that combined deny with not_resources - dpanofsky
    resources = ["arn:aws:s3:::*/*"]
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
}

data "aws_iam_policy_document" "cxm_savings_modifications_policy" {
  count   = var.use_existing_iam_role_policy || !var.enable_savings_modifications ? 0 : 1
  version = "2012-10-17"

  statement {
    sid = "CommitmentManagementPermissions"
    actions = [
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
      # - savingsplans:*
      # NOTE: this is handled by the `arn:aws:iam::aws:policy/AWSSavingsPlansFullAccess` policy attached above - dpanofsky
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "cxm_read_only_policy" {
  count       = var.use_existing_iam_role_policy ? 0 : 1
  name        = local.cxm_read_only_policy_name
  description = "Policy enriching ReadOnly to allow Cloud ex Machina to read the Control Plane without accessing the Data Plane"
  policy      = data.aws_iam_policy_document.cxm_read_only_policy[0].json
  tags        = var.tags
}

resource "aws_iam_policy" "cxm_savings_modifications_policy" {
  count       = var.use_existing_iam_role_policy || !var.enable_savings_modifications ? 0 : 1
  name        = "${var.prefix}-savings-modifications-policy-${random_id.uniq.hex}"
  description = "Policy allowing Cloud ex Machina to manage RI and commitment modifications"
  policy      = data.aws_iam_policy_document.cxm_savings_modifications_policy[0].json
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "cxm_read_only_policy_attachment" {
  count      = var.use_existing_iam_role_policy ? 0 : 1
  role       = local.iam_role_name
  policy_arn = aws_iam_policy.cxm_read_only_policy[0].arn
  depends_on = [module.cxm_cfg_iam_role]
}

resource "aws_iam_role_policy_attachment" "cxm_savings_modifications_policy_attachment" {
  count      = var.use_existing_iam_role_policy || !var.enable_savings_modifications ? 0 : 1
  role       = local.iam_role_name
  policy_arn = aws_iam_policy.cxm_savings_modifications_policy[0].arn
  depends_on = [module.cxm_cfg_iam_role]
}

# ---------------------------------------------------------------------------
# Scheduling & scaling permissions (FinOps cost optimization)
# Controlled by var.enable_scheduling (default: false). Set to true to grant
# CXM permissions to stop/start/scale workloads for cost savings.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "cxm_scheduling_policy" {
  count   = var.use_existing_iam_role_policy || !var.enable_scheduling ? 0 : 1
  version = "2012-10-17"

  statement {
    sid       = "ECSScaling"
    actions   = ["ecs:UpdateService"]
    resources = ["*"]
  }

  statement {
    sid = "EC2StopStart"
    actions = [
      "ec2:StartInstances",
      "ec2:StopInstances",
    ]
    resources = ["*"]
  }

  statement {
    sid = "RDSStopStart"
    actions = [
      "rds:StartDBInstance",
      "rds:StopDBInstance",
      "rds:StartDBCluster",
      "rds:StopDBCluster",
    ]
    resources = ["*"]
  }

  statement {
    sid = "LambdaConcurrency"
    actions = [
      "lambda:PutProvisionedConcurrencyConfig",
      "lambda:DeleteProvisionedConcurrencyConfig",
      "lambda:PutFunctionConcurrency",
      "lambda:DeleteFunctionConcurrency",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "EKSNodegroupScaling"
    actions   = ["eks:UpdateNodegroupConfig"]
    resources = ["*"]
  }

  statement {
    sid = "ASGScaling"
    actions = [
      "autoscaling:UpdateAutoScalingGroup",
      "autoscaling:SetDesiredCapacity",
    ]
    resources = ["*"]
  }

  statement {
    # NOTE: RegisterScalableTarget covers all Application Auto Scaling namespaces
    # (ECS, DynamoDB, AppStream, etc.), not just the services listed above.
    # AWS does not offer namespace-scoped IAM actions for this service.
    sid       = "AppAutoScaling"
    actions   = ["application-autoscaling:RegisterScalableTarget"]
    resources = ["*"]
  }

  statement {
    # NOTE: These actions are broader than scaling alone (they also allow changing
    # engine versions, parameter groups, etc.) but AWS does not offer more granular
    # actions for ElastiCache scaling operations.
    sid = "ElastiCacheScaling"
    actions = [
      "elasticache:ModifyReplicationGroup",
      "elasticache:ModifyCacheCluster",
    ]
    resources = ["*"]
  }

  statement {
    # NOTE: ResizeCluster also allows changing node types (not just counts),
    # which could affect costs. PauseCluster/ResumeCluster are scheduling-only.
    sid = "RedshiftScaling"
    actions = [
      "redshift:PauseCluster",
      "redshift:ResumeCluster",
      "redshift:ResizeCluster",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "SageMakerScaling"
    actions   = ["sagemaker:UpdateEndpointWeightsAndCapacities"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "cxm_scheduling_policy" {
  count       = var.use_existing_iam_role_policy || !var.enable_scheduling ? 0 : 1
  name        = "${var.prefix}-scheduling-${random_id.uniq.hex}"
  description = "Policy granting Cloud ex Machina scheduling and scaling permissions for FinOps cost optimization"
  policy      = data.aws_iam_policy_document.cxm_scheduling_policy[0].json
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "cxm_scheduling_policy_attachment" {
  count      = var.use_existing_iam_role_policy || !var.enable_scheduling ? 0 : 1
  role       = local.iam_role_name
  policy_arn = aws_iam_policy.cxm_scheduling_policy[0].arn
  depends_on = [module.cxm_cfg_iam_role]
}
