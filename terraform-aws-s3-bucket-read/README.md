
# CXM AWS S3 Bucket Read

## Description

This module enables CXM roles to read *Cost and Usage Report* (CUR) bucket, and if allowed, Cloudtrail bucket.

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
| [aws_cloudwatch_event_rule.cxm_bucket_event_rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.cxm_data_plane_bus](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_iam_policy.cxm_cross_account_eventbridge_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.cxm_s3_ro_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.cxm_feedback_loop_iam_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.cxm_cross_account_eventbridge_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.cxm_s3_ro_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_s3_bucket_notification.bucket_notification](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_notification) | resource |
| [random_id.uniq](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [aws_iam_policy_document.cxm_assume_role_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.cxm_cross_account_eventbridge_put_events](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.cxm_s3_ro_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| use_existing_iam_role | Set this to true to use an existing IAM role | `bool` | `false` | no |
| use_existing_iam_role_policy | Set this to `true` to use an existing policy on the IAM role, rather than attaching a new one | `bool` | `false` | no |
| iam_role_arn | The IAM role ARN is required when setting use_existing_iam_role to `true` | `string` | `null` | no |
| iam_role_external_id | The external ID configured inside the IAM role is required when setting use_existing_iam_role to `true` | `string` | `null` | no |
| prefix | Prefix to use for most resources created by this module. | `string` | `"cxm"` | no |
| iam_role_name | The IAM role name. Required to match with iam_role_arn if use_existing_iam_role is set to `true` | `string` | `"cxm-bucket-reader"` | no |
| permission_boundary_arn | Optional - ARN of the policy that is used to set the permissions boundary for the role. | `string` | `null` | no |
| cxm_aws_account_id | The Cloud ex Machina AWS account that the IAM role will grant access | `string` | n/a | yes |
| cxm_role_name | Name of the IAM role in the Cloud ex Machina AWS account that will assume this execution role | `string` | `null` | no |
| s3_bucket_name | Name of the bucket that is used to store CUR data | `string` | n/a | yes |
| s3_bucket_kms_key_arn | Optional - ARN of the KMS Key that is used to encrypt CUR data | `string` | `null` | no |
| cxm_s3_read_policy_name | Name of the IAM Policy to read the bucket. Defaults to cxm-s3-ro-policy-${random_id.uniq.hex} when empty | `string` | `null` | no |
| tags | A map/dictionary of Tags to be assigned to created resources | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
|------|-------------|
| external_id | The External ID configured into the IAM role |
| iam_role_name | The IAM Role name |
| iam_role_arn | The IAM Role ARN |
| s3_bucket_name | Name of the S3 Bucket |
<!-- END_TF_DOCS -->
