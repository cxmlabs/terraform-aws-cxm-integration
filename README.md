
# CXM Integration module

## Description

This module enables CXM roles in your AWS account and organization.

## Usage

Usage example to setup your account, when using AWS Organisation :

```hcl
module "cxm-integration" {
  source  = "cxmlabs/cxm-integration/aws"
  version = "0.1.0"

  providers = {
    aws.root       = aws.root-us-east-1
    aws.cur        = aws.cur
    aws.cloudtrail = aws.cloudtrail
  }

  cxm_external_id    = "ExternalID Provided by Cloud ex Machina"
  cxm_aws_account_id = "123456789123 (provided by Cloud ex Machina)"

  cost_usage_report_bucket_name = "stackset-customcontroltower-cur-report-f-s3bucket-o8nhba42il14"
  cloudtrail_bucket_name        = "aws-controltower-logs-012345678909-us-east-2"

  tags = {
    "MyTag" : "MyTagValue"
  }
}
```

### Module Configuration for a *Lone Account*

If your AWS account is not using AWS Organization, and you have a single "lone" AWS account,
then you could skip the different AWS provider config with multiple profiles
and use the `use_lone_account_instead_of_aws_organization = true` flag :

```hcl
provider "aws" {
  region  = "us-east-1"
  profile = "my-company-account"
}

module "cxm-integration" {
  source  = "cxmlabs/cxm-integration/aws"
  version = "0.1.0"

  providers = {
    aws.root       = aws
    aws.cur        = aws
    aws.cloudtrail = aws
  }

  use_lone_account_instead_of_aws_organization = true  # set this to true if you do not use AWS Organization

  cxm_external_id    = "ExternalID Provided by Cloud ex Machina"
  cxm_aws_account_id = "123456789123 (provided by Cloud ex Machina)"

  cost_usage_report_bucket_name = "cur-s3bucket-o8nhba42il14"
  cloudtrail_bucket_name        = "cloudtrail-logs-012345678909"

  tags = {
    "MyTag" : "MyTagValue"
  }
}
```

### EKS Cluster Enablement

For enabling CXM access to existing EKS clusters, use the dedicated EKS cluster enablement module:

```hcl
module "cxm_eks_enablement" {
  source = "./terraform-aws-eks-cluster-enablement"

  cluster_name = "my-production-cluster"
  # Use the IAM role from the CXM integration module
  iam_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${module.cxm-integration.iam_role_name}"  # Construct ARN from account ID and role name
}
```

This module automatically detects whether your EKS cluster supports modern access entries or requires the legacy aws-auth ConfigMap approach. The `cxm_iam_role_arn` output automatically selects the appropriate IAM role based on your deployment type (lone account vs organization). For detailed usage instructions, examples, and configuration options, see the [EKS cluster enablement module documentation](./terraform-aws-eks-cluster-enablement/README.md).

### About providers

Providers should be setup based on where you store your CUR bucket and your cloudtrail logs bucket.

```hcl
# Provider for the AWS Organization Management Account in us-east-1
# Required to deploy the CUR Crawler
provider "aws" {
  region  = "us-east-1"
  profile = "org-root"
  alias   = "root-us-east-1"
}

# Provider for the AWS Organization Billing Account in the same region as the
# Cost & Usage Report (CUR) bucket
provider "aws" {
  region  = "eu-west-1"
  profile = "org-cur"
  alias   = "cur"
}

# Provider for the AWS Organization Log Archive Account in the same region as the
# Log Archive Bucket
provider "aws" {
  region  = "us-east-2"
  profile = "org-log-archive"
  alias   = "cloudtrail"
}
```


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
| enable_benchmarking_account | ./terraform-aws-benchmarking-account-enablement | n/a |
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
| enable_benchmarking | Enabled benchmarking to authorize pro-active rightsizing optimization of resources. Disabled by default. | `bool` | `false` | no |
| deployment_targets | Add a filter, and list of Organizational Units from the Organization to only deploy to. If left blank, all organization will be crawled by default. | `set(any)` | `[]` | no |
| permission_boundary_arn | Optional - ARN of the policy that is used to set the permissions boundary for the role. | `string` | `null` | no |
| s3_kms_key_arn | Optional - ARN of the KMS Key that is used to encrypt CUR data | `string` | `null` | no |
| prefix | Optional - prefix for key constructs created by this module. | `string` | `"cxm"` | no |
| role_suffix | Optional - suffix to append to roles names. | `string` | `null` | no |
| tags | A map/dictionary of Tags to be assigned to created resources | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
|------|-------------|
| lone_account_iam_role_arn | ARN of the CXM IAM role for lone account deployment |
| organization_iam_role_arn | ARN of the CXM IAM role for organization root deployment |
| benchmarking_iam_role_arn | ARN of the CXM IAM role for benchmarking account |
| cxm_iam_role_name | Name of the CXM IAM role (automatically selects between lone account or organization deployment) |
<!-- END_TF_DOCS -->
