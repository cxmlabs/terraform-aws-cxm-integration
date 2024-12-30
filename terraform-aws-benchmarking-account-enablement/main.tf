locals {
  iam_role_arn         = module.cxm_cfg_iam_role.created ? module.cxm_cfg_iam_role.arn : var.iam_role_arn
  iam_role_name        = module.cxm_cfg_iam_role.created ? module.cxm_cfg_iam_role.name : var.iam_role_name
  iam_role_external_id = module.cxm_cfg_iam_role.created ? module.cxm_cfg_iam_role.external_id : var.cxm_external_id
  cxm_benchmarking_policy_name = (
    length(var.cxm_benchmarking_policy_name) > 0 ? var.cxm_benchmarking_policy_name : "cxm-benchmarking-${random_id.uniq.hex}"
  )
}

resource "random_id" "uniq" {
  byte_length = 4
}

module "cxm_cfg_iam_role" {
  source                  = "../terraform-aws-iam-role"
  dry_run                 = var.use_existing_iam_role ? true : false
  iam_role_name           = var.iam_role_name
  permission_boundary_arn = var.permission_boundary_arn
  cxm_aws_account_id      = var.cxm_aws_account_id
  external_id             = var.use_existing_iam_role ? "" : var.cxm_external_id
  tags                    = var.tags
}

resource "aws_iam_role_policy_attachment" "lambda_read_only_access_policy_attachment" {
  count      = var.use_existing_iam_role_policy ? 0 : 1
  role       = local.iam_role_name
  policy_arn = "arn:aws:iam::aws:policy/AWSLambda_ReadOnlyAccess"
  depends_on = [module.cxm_cfg_iam_role]
}

resource "aws_iam_role_policy_attachment" "lambda_invoke_policy_attachment" {
  count      = var.use_existing_iam_role_policy ? 0 : 1
  role       = local.iam_role_name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaRole"
  depends_on = [module.cxm_cfg_iam_role]
}


data "aws_iam_policy_document" "cxm_benchmarking_policy" {
  count   = var.use_existing_iam_role_policy ? 0 : 1
  version = "2012-10-17"

  statement {
    # Explicitely grant creation of Lambda versions, aliases and configurations
    sid    = "LambdaBenchmarkingEnablement"
    effect = "Allow"
    actions = [
      "lambda:PublishVersion",
      "lambda:UpdateFunctionConfiguration",
      "lambda:CreateAlias",
      "lambda:UpdateAlias",
    ]
    resources = ["arn:aws:lambda:*:*:function:*"]
  }

  statement {
    # Authorizes Garbage collection of resources created for benchmarking
    sid    = "LambdaBenchmarkingGarbageCollection"
    effect = "Allow"
    actions = [
      "lambda:DeleteAlias",
      "lambda:DeleteFunction",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "cxm_benchmarking_policy" {
  count       = var.use_existing_iam_role_policy ? 0 : 1
  name        = local.cxm_benchmarking_policy_name
  description = "Policy allowing Cloud ex Machina to benchmark lambda functions"
  policy      = data.aws_iam_policy_document.cxm_benchmarking_policy[0].json
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "cxm_benchmarking_policy_attachment" {
  count      = var.use_existing_iam_role_policy ? 0 : 1
  role       = local.iam_role_name
  policy_arn = aws_iam_policy.cxm_benchmarking_policy[0].arn
  depends_on = [module.cxm_cfg_iam_role]
}
