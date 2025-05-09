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
  policy_arn = "arn:aws:iam::aws:policy/ServiceQuotasFullAccess"
  depends_on = [module.cxm_cfg_iam_role]
}

# This is required in fully manage Savings Plans
resource "aws_iam_role_policy_attachment" "crawler_manage_sp_policy_attachment" {
  count      = var.use_existing_iam_role_policy ? 0 : 1
  role       = local.iam_role_name
  policy_arn = "arn:aws:iam::aws:policy/AWSSavingsPlansFullAccess"
  depends_on = [module.cxm_cfg_iam_role]
}

data "aws_iam_policy_document" "cxm_read_only_policy" {
  count   = var.use_existing_iam_role_policy ? 0 : 1
  version = "2012-10-17"

  statement {
    # Understand configuration and enrollment of accounts into financial optimizations
    sid = "CommitmentManagementPermissions"
    actions = [
      # DynamoDB Reservations
      "dynamodb:DescribeReservedCapacity",
      "dynamodb:DescribeReservedCapacityOfferings",
      "dynamodb:PurchaseReservedCapacityOfferings",
      # EC2 Reservations
      "ec2:DescribeReserved*",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeRegions",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeTags",
      "ec2:GetReserved*",
      "ec2:ModifyReservedInstances",
      "ec2:PurchaseReservedInstancesOffering",
      "ec2:CreateReservedInstancesListing",
      "ec2:CancelReservedInstancesListing",
      "ec2:GetReservedInstancesExchangeQuote",
      "ec2:AcceptReservedInstancesExchangeQuote",
      # RDS Reservations
      "rds:DescribeReserved*",
      "rds:ListTagsForResource*",
      "rds:PurchaseReservedDBInstancesOffering",
      # Redshift Reservations
      "redshift:DescribeReserved*",
      "redshift:DescribeTags",
      "redshift:GetReserved*",
      "redshift:AcceptReservedNodeExchange",
      "redshift:PurchaseReservedNodeOffering",
      # ElastiCache Reservations
      "elasticache:DescribeReserved*",
      "elasticache:ListTagsForResource",
      "elasticache:PurchaseReservedCacheNodesOffering",
      # ElasticSearch Reservations
      "es:DescribeReserved*",
      "es:ListTags",
      "es:PurchaseReservedElasticsearchInstanceOffering",
      "es:PurchaseReservedInstanceOffering",
      # memoryDB
      "memorydb:DescribeReserved*",
      "memorydb:ListTags",
      "memorydb:PurchaseReservedNodesOffering",
      # Saving Plans full management
      "savingsplans:*"
    ]
    resources = ["*"]
  }

  statement {
    # Explicitly removing read access to S3 objects
    sid           = "ExplicitDenyOnS3Files"
    effect        = "Deny"
    actions       = ["s3:GetObject"]
    not_resources = ["arn:aws:s3:::*/*"]
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

resource "aws_iam_policy" "cxm_read_only_policy" {
  count       = var.use_existing_iam_role_policy ? 0 : 1
  name        = local.cxm_read_only_policy_name
  description = "Policy enriching ReadOnly to allow Cloud ex Machina to read the Control Plane without accessing the Data Plane"
  policy      = data.aws_iam_policy_document.cxm_read_only_policy[0].json
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "cxm_read_only_policy_attachment" {
  count      = var.use_existing_iam_role_policy ? 0 : 1
  role       = local.iam_role_name
  policy_arn = aws_iam_policy.cxm_read_only_policy[0].arn
  depends_on = [module.cxm_cfg_iam_role]
}
