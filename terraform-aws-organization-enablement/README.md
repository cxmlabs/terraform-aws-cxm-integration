
# CXM AWS Organization Enablement

## Description

This module enables CXM roles to crawl your AWS Organization in order to list resources.
It also forbids CXM to access any customer data other than cloud usage & metrics.

## Terraform doc

<!-- BEGIN_TF_DOCS -->
### Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| aws | >= 3.74.0 |
| random | >= 2.1 |

### Providers

| Name | Version |
|------|---------|
| random | >= 2.1 |
| aws | >= 3.74.0 |

### Modules

| Name | Source | Version |
|------|--------|---------|
| cxm_cfg_iam_role | ../terraform-aws-iam-role | n/a |

### Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_event_rule.cxm_organization_access_event_rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_rule.cxm_organization_changes_event_rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_rule.cxm_organization_cloudformation_rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.cxm_organization_access_event_target](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_event_target.cxm_organization_changes_event_target](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_event_target.cxm_organization_cloudformation_event_target](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_iam_policy.cxm_cross_account_eventbridge_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.cxm_organization_read_only_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.cxm_feedback_loop_iam_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.crawler_manage_ri_quotas_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.crawler_manage_sp_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.crawler_read_only_access_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.cxm_cross_account_eventbridge_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.cxm_organization_read_only_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.organization_read_only_access_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [random_id.uniq](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [aws_iam_policy_document.cxm_assume_role_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.cxm_cross_account_eventbridge_put_events](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.cxm_organization_read_only_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| cxm_aws_account_id | The Cloud ex Machina AWS account that the IAM role will grant access from. Provided by CXM. | `string` | n/a | yes |
| cxm_external_id | External ID to use in the trust relationship. Provided by CXM. | `string` | n/a | yes |
| use_existing_iam_role | Set this to some IAM role arn to force usage of an existing IAM role (default null) | `string` | `null` | no |
| use_existing_iam_role_policy | Set this to `true` to use an existing policy on the IAM role. | `bool` | `false` | no |
| prefix | Prefix to use to name import constructs such as IAM roles when they are not set otherwise | `string` | `"cxm"` | no |
| iam_role_name | The IAM role name. Required to match with iam_role_arn if use_existing_iam_role is set to `true`. Note tht this name will be prefixed when left empty | `string` | `"organization-crawler"` | no |
| permission_boundary_arn | Optional - ARN of the policy that is used to set the permissions boundary for the role. | `string` | `null` | no |
| cxm_read_only_policy_name | The name of the policy used to authorize Cloud ex Machina to read the AWS Organizations API.  Defaults to cxm-organizations-ro-${random_id.uniq.hex} when empty. | `string` | `null` | no |
| tags | A map of K:V pairs to use as tags on all resources. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
|------|-------------|
| external_id | The External ID configured into the IAM role. |
| iam_role_name | The IAM Role name. |
| iam_role_arn | The IAM Role ARN. |
<!-- END_TF_DOCS -->
