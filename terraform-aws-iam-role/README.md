
# CXM AWS IAM Role

## Description

This is a sub module that creates a role that only CXM can use.

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

No modules.

### Resources

| Name | Type |
|------|------|
| [aws_iam_role.cxm_iam_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [random_id.uniq](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [aws_iam_policy_document.cxm_assume_role_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| dry_run | Setting dry_run to `true` will prevent the module from creating new resources. | `bool` | `false` | no |
| iam_role_name | The IAM role name | `string` | `""` | no |
| cxm_aws_account_id | The Cloud ex Machina AWS account that the IAM role will grant access. | `string` | `"596683793973"` | no |
| cxm_role_name | Name of the IAM role in the Cloud ex Machina AWS account that will assume this execution role | `string` | `""` | no |
| external_id | External ID provided by Cloud ex Machina to configure the role. | `string` | `""` | no |
| permission_boundary_arn | Optional - ARN of the policy that is used to set the permissions boundary for the role. | `string` | `null` | no |
| tags | A map/dictionary of Tags to be assigned to created resources. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
|------|-------------|
| created | Indicates if the resources specified in the module were created or not. |
| name | IAM Role Name. |
| arn | IAM Role ARN. |
| external_id | The External ID provided by Cloud ex Machina to configure the IAM role. |
<!-- END_TF_DOCS -->
