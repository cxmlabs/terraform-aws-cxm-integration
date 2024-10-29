
# CXM Integration module

## Description

This module enables CXM roles in your AWS account and organization.

## Terraform doc

<!-- BEGIN_TF_DOCS -->
### Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| aws | ~> 5.0 |

### Providers

No providers.

### Modules

| Name | Source | Version |
|------|--------|---------|
| enable_root_organization | ./terraform-aws-organization-enablement | n/a |
| enable_sub_accounts | ./terraform-aws-full-organization-enablement | n/a |
| enable_lone_account | ./terraform-aws-account-enablement | n/a |
| enable_cur | ./terraform-aws-s3-bucket-read | n/a |
| enable_cloudtrail | ./terraform-aws-s3-bucket-read | n/a |

### Resources

No resources.

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| cxm_aws_account_id | The Cloud ex Machina AWS account that the IAM role will grant access to. Provided by CXM. | `string` | n/a | yes |
| cxm_external_id | External ID to use in the trust relationship. Provided by CXM. | `string` | n/a | yes |
| cost_usage_report_bucket_name | Name of the bucket that is used to store CUR data. Should be set if disable_cur_analysis is not set. | `string` | n/a | yes |
| cloudtrail_bucket_name | Name of the bucket that is used to store Cloudtrail data. Should be set if disable_cloudtrail_analysis is not set. | `string` | `null` | no |
| disable_asset_discovery | Disable asset discovery permissions. This is strongly discouraged and will limit a lot the services provided by CXM. Enable by default. | `bool` | `false` | no |
| disable_cloudtrail_analysis | Disable Cloudtrail analysis permissions. This is strongly discouraged and will limit a lot the services provided by CXM. Enable by default. | `bool` | `false` | no |
| use_lone_account_instead_of_aws_organization | If your AWS account is not using AWS Organization and is considered a 'lone account', set this to true. This will enable CXM on a single account. False by default. | `bool` | `false` | no |
| deployment_targets | Add a filter, and list of Organizational Units from the Organization to only deploy to. If left blank, all organization will be crawled by default. | `set(any)` | `[]` | no |
| permission_boundary_arn | Optional - ARN of the policy that is used to set the permissions boundary for the role. | `string` | `null` | no |
| s3_kms_key_arn | Optional - ARN of the KMS Key that is used to encrypt CUR data | `string` | `null` | no |
| tags | A map/dictionary of Tags to be assigned to created resources | `map(string)` | `{}` | no |

### Outputs

No outputs.
<!-- END_TF_DOCS -->
