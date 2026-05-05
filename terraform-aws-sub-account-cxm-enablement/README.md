# CXM Sub-Account Enablement (Terraform-Native)

Deploys CXM asset-crawler IAM roles and EventBridge feedback loop into a single AWS sub-account using pure Terraform. This is the Terraform-native alternative to the CloudFormation StackSet approach used by the root module.

## When to use this module

| Scenario | Recommended approach |
|----------|---------------------|
| Full org, auto-deploy to new accounts | Root module with StackSet ([Section 4](https://github.com/cxmlabs/terraform-aws-cxm-integration/blob/main/GUIDE.md#section-4-full-organization-setup)) |
| OU-scoped StackSet deployment | Root module with `deployment_targets` ([Section 3](https://github.com/cxmlabs/terraform-aws-cxm-integration/blob/main/GUIDE.md#section-3-deploy-to-a-single-ou)) |
| Terraform-only (no CloudFormation) | **This module** — one block per account |
| Selective accounts, full Terraform control | **This module** — one block per account |
| Terragrunt multi-account automation | **This module** + Terragrunt (see [tips below](#terragrunt)) |

## Understanding the two roles

This module involves **two distinct IAM roles** that serve very different purposes:

### 1. Provisioning role (Terraform)

The role Terraform uses **to create resources** in the target sub-account. You configure this in your provider block — the module itself doesn't manage authentication.

```
Your workstation / CI
  └─ terraform apply
       └─ provider "aws" with assume_role / profile / SSO
            └─ creates IAM roles, EventBridge rules in sub-account
```

Common provisioning approaches:

| Method | Example |
|--------|---------|
| `assume_role` into `OrganizationAccountAccessRole` | Default AWS Organizations role in every member account |
| `assume_role` into `AWSControlTowerExecution` | If you use AWS Control Tower |
| AWS SSO / IAM Identity Center profile | `profile = "sso-engineering-admin"` |
| Any cross-account role | Your custom Terraform execution role |

The provisioning role needs IAM and EventBridge write permissions in the target account.

### 2. Runtime role (CXM)

The `cxm-asset-crawler` role **created by this module**. CXM assumes this role at runtime to read your account's resources. It has read-only access plus commitment management permissions, with explicit data-plane denies.

```
CXM Platform
  └─ cxm-organization-crawler (management account)
       └─ assumes ──► cxm-asset-crawler (sub-account)  ← created by this module
            └─ reads EC2, RDS, ECS, ... (ReadOnlyAccess)
            └─ manages reservations, savings plans
            └─ DENIED: data reads (DynamoDB, S3 objects, logs, etc.)
```

The provisioning role is only used during `terraform apply`. The runtime role is used continuously by the CXM platform.

## Prerequisites

- [Section 1: Organization Foundation](https://github.com/cxmlabs/terraform-aws-cxm-integration/blob/main/GUIDE.md#section-1-organization-foundation) deployed (provides the `organization_iam_role_arn` needed for `cxm_admin_role_arn`)
- Terraform >= 1.5.0 and AWS provider >= 5.0
- A provider configured to authenticate into each target sub-account

## Usage

Configure one provider per sub-account, then pass it to the module:

```hcl
# Providers — one per sub-account
provider "aws" {
  alias  = "engineering"
  region = "us-east-1"
  assume_role {
    role_arn = "arn:aws:iam::111111111111:role/OrganizationAccountAccessRole"
  }
}

provider "aws" {
  alias  = "staging"
  region = "us-east-1"
  assume_role {
    role_arn = "arn:aws:iam::222222222222:role/OrganizationAccountAccessRole"
  }
}

provider "aws" {
  alias  = "production"
  region = "us-east-1"
  assume_role {
    role_arn = "arn:aws:iam::333333333333:role/AWSControlTowerExecution"
  }
}

# Module blocks
module "cxm_sub_account_engineering" {
  source  = "cxmlabs/cxm-integration/aws//terraform-aws-sub-account-cxm-enablement"


  providers = { aws = aws.engineering }

  cxm_aws_account_id = "REPLACE_WITH_CXM_ACCOUNT_ID"
  cxm_external_id    = "REPLACE_WITH_CXM_EXTERNAL_ID"
  cxm_admin_role_arn = module.cxm_integration.organization_iam_role_arn

  tags = { "ManagedBy" = "terraform" }
}

module "cxm_sub_account_staging" {
  source  = "cxmlabs/cxm-integration/aws//terraform-aws-sub-account-cxm-enablement"


  providers = { aws = aws.staging }

  cxm_aws_account_id = "REPLACE_WITH_CXM_ACCOUNT_ID"
  cxm_external_id    = "REPLACE_WITH_CXM_EXTERNAL_ID"
  cxm_admin_role_arn = module.cxm_integration.organization_iam_role_arn

  tags = { "ManagedBy" = "terraform" }
}

module "cxm_sub_account_production" {
  source  = "cxmlabs/cxm-integration/aws//terraform-aws-sub-account-cxm-enablement"


  providers = { aws = aws.production }

  cxm_aws_account_id = "REPLACE_WITH_CXM_ACCOUNT_ID"
  cxm_external_id    = "REPLACE_WITH_CXM_EXTERNAL_ID"
  cxm_admin_role_arn = module.cxm_integration.organization_iam_role_arn

  enable_scheduling = true  # Grants stop/start/scale permissions for FinOps

  tags = { "ManagedBy" = "terraform" }
}
```

### Discovering account IDs

Use the root module's `discovered_account_ids` output to list all active member accounts:

```bash
terraform output discovered_account_ids
```

Or query AWS Organizations directly:

```bash
aws organizations list-accounts \
  --profile org-root \
  --query 'Accounts[?Status==`ACTIVE`].[Id,Name]' \
  --output table
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `cxm_aws_account_id` | CXM AWS account ID (provided by CXM) | `string` | — | yes |
| `cxm_external_id` | External ID for the CXM trust relationship (provided by CXM) | `string` | — | yes |
| `cxm_admin_role_arn` | ARN of the organization-crawler role in the management account | `string` | — | yes |
| `prefix` | Prefix for all resource names | `string` | `"cxm"` | no |
| `role_suffix` | Suffix appended to IAM role names | `string` | `""` | no |
| `enable_scheduling` | Enable scheduling/scaling permissions for FinOps cost optimization | `bool` | `false` | no |
| `permission_boundary_arn` | ARN of a permissions boundary policy for created IAM roles | `string` | `null` | no |
| `tags` | Tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `iam_role_arn` | ARN of the CXM asset-crawler IAM role |
| `iam_role_name` | Name of the CXM asset-crawler IAM role |
| `feedback_loop_role_arn` | ARN of the feedback loop IAM role for EventBridge forwarding |

## Tips for OpenTofu and Terragrunt

### OpenTofu

OpenTofu 1.9+ supports `for_each` on provider blocks, which combined with module `for_each` can reduce boilerplate significantly. Since this module accepts an external provider, you can combine both features. See the [OpenTofu documentation on provider for_each](https://opentofu.org/docs/language/providers/configuration/#for_each-multiple-provider-configurations) for the exact syntax.

> **Note:** Standard Terraform does not support `for_each` on provider blocks. This is an OpenTofu-only feature.

### Terragrunt

Use Terragrunt to loop over accounts with a provider generated per account:

```hcl
# terragrunt.hcl (in each account directory)
terraform {
  source = "cxmlabs/cxm-integration/aws//terraform-aws-sub-account-cxm-enablement"
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "us-east-1"
  assume_role {
    role_arn = "arn:aws:iam::${local.account_id}:role/OrganizationAccountAccessRole"
  }
}
EOF
}

inputs = {
  cxm_aws_account_id = "REPLACE_WITH_CXM_ACCOUNT_ID"
  cxm_external_id    = "REPLACE_WITH_CXM_EXTERNAL_ID"
  cxm_admin_role_arn = dependency.org.outputs.organization_iam_role_arn
}
```

With `read_terragrunt_config` and a shared config, you can DRY this across many accounts. See the [Terragrunt documentation](https://terragrunt.gruntwork.io/docs/) for patterns.
