
# CXM AWS Sub-Accounts Enablement

## Description

This module enables CXM roles to crawl the sub-accounts in your AWS Organization in order to list resources.
It also forbids CXM to access any customer data other than cloud usage & metrics.

## Terraform doc

<!-- BEGIN_TF_DOCS -->
### Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| aws | >= 3.74.0 |

### Providers

| Name | Version |
|------|---------|
| aws | >= 3.74.0 |

### Modules

No modules.

### Resources

| Name | Type |
|------|------|
| [aws_cloudformation_stack_set.cxm_account_enablement](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack_set) | resource |
| [aws_cloudformation_stack_set_instance.cxm_account_enablement](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack_set_instance) | resource |

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| cxm_aws_account_id | The Cloud ex Machina AWS account that the IAM role will grant access. | `string` | n/a | yes |
| cxm_external_id | External ID to use in the trust relationship. | `string` | n/a | yes |
| cxm_admin_role_arn | The ARN of the role created in the AWS Organizations root account that will be used as a relay. | `string` | n/a | yes |
| deployment_targets | A list of Organizational Units from the Organization to deploy to. | `set(any)` | `[]` | no |
| prefix | Prefix to use for all resources created by this module. | `string` | `"cxm"` | no |
| stack_and_role_suffix | Suffix to use for the cloudformation stack. | `string` | `null` | no |

### Outputs

| Name | Description |
|------|-------------|
| cxm_external_id | External ID to use in the trust relationship. |
| cxm_aws_account_id | The Cloud ex Machina AWS account that the IAM role will grant access. |
| prefix | Prefix to use for all resources created by this module. |
<!-- END_TF_DOCS -->
