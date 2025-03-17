locals {
  stack_and_role_suffix = var.stack_and_role_suffix != null ? "-${var.stack_and_role_suffix}" : ""
}

resource "aws_cloudformation_stack_set" "cxm_account_enablement" {
  name = "${var.prefix}-account-enablement${local.stack_and_role_suffix}"
  auto_deployment {
    enabled                          = true
    retain_stacks_on_account_removal = false
  }
  capabilities     = ["CAPABILITY_NAMED_IAM"]
  permission_model = "SERVICE_MANAGED"

  parameters = {
    Prefix            = var.prefix
    CXMExternalID     = var.cxm_external_id
    CustomerAccountID = var.cxm_aws_account_id
    AdminRoleArn      = var.cxm_admin_role_arn
    RoleSuffix        = local.stack_and_role_suffix
  }

  template_body = file("${path.module}/cxm-aws-account-enablement.yaml")

  administration_role_arn = null # leave blank to auto detect
  lifecycle {
    ignore_changes = [administration_role_arn]
  }
}

resource "aws_cloudformation_stack_set_instance" "cxm_account_enablement" {
  deployment_targets {
    organizational_unit_ids = var.deployment_targets
  }

  region         = "us-east-1"
  stack_set_name = aws_cloudformation_stack_set.cxm_account_enablement.name
  operation_preferences {
    failure_tolerance_count = 0
    max_concurrent_count    = 10
    region_concurrency_type = "PARALLEL"
  }
}
