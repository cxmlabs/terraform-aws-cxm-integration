
# CXM AWS Lone Account Enablement

## Description

This module enables CXM roles to crawl a AWS lone account (that does not have AWS Organization enabled) in order to list resources.
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
| [aws_iam_policy.cxm_read_only_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role_policy_attachment.cxm_read_only_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.read_only_access_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [random_id.uniq](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [aws_iam_policy_document.cxm_read_only_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| cxm_aws_account_id | The Cloud ex Machina AWS account that the IAM role will grant access. | `string` | n/a | yes |
| cxm_external_id | External ID to use in the trust relationship. Required to match the existing External ID when setting use_existing_iam_role to `true`. | `string` | n/a | yes |
| iam_role_name | Name of the IAM role to set. Required to match with iam_role_arn if use_existing_iam_role is set to `true`. | `string` | n/a | yes |
| use_existing_iam_role | Set to true in order to use a pre-existing IAM role. Set iam_role_arn if you do. | `bool` | `false` | no |
| use_existing_iam_role_policy | Set this to `true` to use an existing policy on the IAM role, rather than attaching a new one. | `bool` | `false` | no |
| iam_role_arn | IAM role ARN to use. Required when setting use_existing_iam_role to `true`. | `string` | `""` | no |
| permission_boundary_arn | Optional - ARN of a policy that is used to contraint permissions boundary for the role. | `string` | `null` | no |
| cxm_read_only_policy_name | The name of the policy used to enrich ReadOnly to allow Cloud ex Machina to read the Control Plane.  Defaults to cxm-account-ro-${random_id.uniq.hex} when empty. | `string` | `""` | no |
| tags | A map/dictionary of Tags to be assigned to created resources. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
|------|-------------|
| external_id | The External ID configured into the IAM role |
| iam_role_name | The IAM Role name |
| iam_role_arn | The IAM Role ARN |
<!-- END_TF_DOCS -->
