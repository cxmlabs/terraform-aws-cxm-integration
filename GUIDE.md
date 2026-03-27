# CXM Integration - Step-by-Step Installation Guide

## How to use this guide

Every CXM deployment starts with **[Section 1: Organization Foundation](#section-1-organization-foundation)** — this sets up the management account with the organization crawler and CUR reader. From there, choose how broadly to deploy asset crawlers to member accounts:

### Production deployment

> Section 1 + Section 4

Deploy CXM across your entire AWS Organization. All current and future member accounts automatically receive CXM roles.

1. [Section 1: Organization Foundation](#section-1-organization-foundation) — management account setup
2. [Section 4: Full Organization Setup](#section-4-full-organization-setup) — deploy to all member accounts via StackSets

### PoC / PoV deployment

> Section 1 + (Section 2 and/or Section 3)

Validate the CXM integration on a limited scope before rolling out to production. Combine any of:

1. [Section 1: Organization Foundation](#section-1-organization-foundation) — management account setup (always required)
2. Then pick one or more:
   - [Section 2: Lone Account Setup](#section-2-lone-account-setup) — enable metadata crawling on specific individual accounts
   - [Section 3: Deploy to a Single OU](#section-3-deploy-to-a-single-ou) — deploy to all accounts within a specific OU

When the PoC is validated, move to production by replacing Sections 2/3 with [Section 4](#section-4-full-organization-setup).

### Optional add-ons

These can be added to any deployment above:

| Add-on | Section | Description |
|--------|---------|-------------|
| EKS cluster access | [Bonus: EKS](#bonus-eks-cluster-enablement) | Grant CXM read-only access to EKS clusters |
| CloudTrail analysis | [Enabling CloudTrail](#enabling-cloudtrail-analysis-optional) | Let CXM analyze CloudTrail logs for deeper usage insights |
| VPC Flow Logs analysis | [Enabling Flow Logs](#enabling-vpc-flow-logs-analysis-optional) | Let CXM analyze centralized VPC Flow Logs from S3 |
| Additional variables | [Optional Configuration](#optional-configuration) | Prefix, suffix, permission boundaries, KMS keys, scheduling |

---

## Section 1: Organization Foundation

**What this does:** Creates the CXM organization crawler IAM role in your management account and a CUR reader role in the account hosting your Cost and Usage Reports. This is a prerequisite for Sections 3 and 4 (StackSet deployment to member accounts).

### Prerequisites

- [ ] Terraform >= 1.5.0 installed
- [ ] AWS CLI configured with profiles for your management account and CUR account
- [ ] CXM-provided credentials: `cxm_aws_account_id` and `cxm_external_id`
- [ ] AWS provider `~> 5.0`

### Information you need

| Value | Description | Example |
|-------|-------------|---------|
| `cxm_aws_account_id` | CXM AWS account ID (provided by CXM) | `123456789012` |
| `cxm_external_id` | External ID for trust relationship (provided by CXM) | `abc123-def456` |
| CUR bucket name | S3 bucket storing Cost and Usage Reports | `my-cur-bucket` |
| CUR bucket region | AWS region of the CUR bucket (the `aws.cur` provider **must** use this region) | `eu-west-1` |
| CUR bucket account profile | AWS CLI profile for the account hosting the CUR bucket | `org-billing` |
| Management account profile | AWS CLI profile for the Organization management account | `org-root` |

### Step 1: Create the Terraform configuration

Create a new directory and add the following files.

**`provider.tf`** - Configure one provider per account/region:

> **Region requirements:**
> - `aws.cur` **must** be in the **same region** as the CUR S3 bucket. The module creates S3 bucket notifications and EventBridge rules that only work in the bucket's region.
> - `aws.root` can be any region. It determines where EventBridge rules for Organization change notifications are created. IAM roles are global and work regardless of region.

```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Provider for the Organization Management Account
provider "aws" {
  region  = "eu-west-1"        # <-- Change to your management account's preferred region
  profile = "org-root"         # <-- Change to your management account profile
  alias   = "root"
}

# Provider for the CUR bucket account — MUST be in the same region as the CUR bucket
provider "aws" {
  region  = "eu-west-1"        # <-- MUST match your CUR bucket's region
  profile = "org-billing"      # <-- Change to your CUR account profile
  alias   = "cur"
}
```

**`main.tf`** - Invoke the CXM module:

```hcl
module "cxm_integration" {
  source  = "cxmlabs/cxm-integration/aws"
  version = "0.4.2"

  providers = {
    aws.root       = aws.root
    aws.cur        = aws.cur
    aws.cloudtrail = aws.root  # Not used — CloudTrail analysis is disabled below
    aws.flowlogs   = aws.root  # Not used — Flow Logs analysis is disabled by default
  }

  cxm_aws_account_id = "REPLACE_WITH_CXM_ACCOUNT_ID"
  cxm_external_id    = "REPLACE_WITH_CXM_EXTERNAL_ID"

  cost_usage_report_bucket_name = "REPLACE_WITH_CUR_BUCKET_NAME"
  disable_cloudtrail_analysis   = true

  tags = {
    "ManagedBy" = "terraform"
    "Purpose"   = "cxm-integration"
  }
}
```

> **Want CloudTrail analysis too?** See [Enabling CloudTrail Analysis (Optional)](#enabling-cloudtrail-analysis-optional) to add it.

### Step 2: Initialize and apply

```bash
terraform init
terraform plan
terraform apply
```

### Step 3: Verify your deployment

```bash
# Check the outputs
terraform output organization_iam_role_arn
terraform output cxm_iam_role_name
```

You can also verify in the AWS Console:
- **IAM > Roles** in the management account: look for `cxm-organization-crawler`
- **IAM > Roles** in the CUR account: look for `cxm-cur-reader`
- **EventBridge > Rules** in the management account: look for rules prefixed with `cxm`

### What was created

| Resource | Account | Description |
|----------|---------|-------------|
| `cxm-organization-crawler` IAM role | Management | Reads Organization structure, accounts, SSO, commitments |
| `cxm-cur-reader` IAM role | CUR account | Read-only access to the CUR S3 bucket |
| EventBridge rules | Management | Notifies CXM of Organization and CloudFormation changes |
| EventBridge rules | CUR account | Notifies CXM when new CUR data arrives |
| Feedback loop IAM roles | Each account | Allows EventBridge to forward events cross-account to CXM |

> **Next step:** To deploy asset crawlers to member accounts, continue with [Section 3](#section-3-deploy-to-a-single-ou) (single OU) or [Section 4](#section-4-full-organization-setup) (all accounts).

---

## Section 2: Lone Account Setup

**What this does:** Sets up CXM metadata crawling on a **single AWS account**. This is ideal for a **PoC/PoV** to validate the CXM integration on one account before rolling out to your full organization.

> **Note:** The target account **can** be part of an AWS Organization — "lone account" means CXM is deployed to just that one account rather than across the org. This setup works alongside a [Section 1](#section-1-organization-foundation) deployment on the management account (which handles CUR and CloudTrail centrally). When you're ready to move to production, deploy to all member accounts using [Section 3](#section-3-deploy-to-a-single-ou) or [Section 4](#section-4-full-organization-setup).

### Prerequisites

- [ ] Terraform >= 1.5.0 installed
- [ ] AWS CLI configured with a profile for your account
- [ ] CXM-provided credentials: `cxm_aws_account_id` and `cxm_external_id`
- [ ] AWS provider `~> 5.0`

### Information you need

| Value | Description | Example |
|-------|-------------|---------|
| `cxm_aws_account_id` | CXM AWS account ID (provided by CXM) | `123456789012` |
| `cxm_external_id` | External ID for trust relationship (provided by CXM) | `abc123-def456` |
| Account profile | AWS CLI profile for your account | `my-company-account` |
| Account region | AWS region for your account | `eu-west-1` |

### Step 1: Create the Terraform configuration

**`provider.tf`** - A single provider is enough since everything is in one account:

```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = "eu-west-1"          # <-- Change to your preferred region
  profile = "my-company-account" # <-- Change to your profile
}
```

**`main.tf`** - All provider aliases point to the same provider. CUR and CloudTrail are disabled since they are handled centrally via the organization setup:

```hcl
module "cxm_integration" {
  source  = "cxmlabs/cxm-integration/aws"
  version = "0.4.2"

  providers = {
    aws.root       = aws
    aws.cur        = aws  # Not used — CUR analysis is disabled below
    aws.cloudtrail = aws  # Not used — CloudTrail analysis is disabled below
    aws.flowlogs   = aws  # Not used — Flow Logs analysis is disabled by default
  }

  use_lone_account_instead_of_aws_organization = true
  disable_cur_analysis                         = true
  disable_cloudtrail_analysis                  = true

  cxm_aws_account_id = "REPLACE_WITH_CXM_ACCOUNT_ID"
  cxm_external_id    = "REPLACE_WITH_CXM_EXTERNAL_ID"

  tags = {
    "ManagedBy" = "terraform"
    "Purpose"   = "cxm-integration-poc"
  }
}
```

> **CUR data on this account?** If this lone account contains a CUR data export you want to analyze, activate CUR analysis by setting `disable_cur_analysis = false` and adding `cost_usage_report_bucket_name = "your-cur-bucket"`. The provider region **must** match the CUR bucket's region in that case.

### Step 2: Initialize and apply

```bash
terraform init
terraform plan
terraform apply
```

### Step 3: Verify your deployment

```bash
# Check the outputs
terraform output lone_account_iam_role_arn
terraform output cxm_iam_role_name
```

Verify in the AWS Console:
- **IAM > Roles**: look for `cxm-organization-crawler`
- **EventBridge > Rules**: look for rules prefixed with `cxm`

### What was created

| Resource | Description |
|----------|-------------|
| `cxm-organization-crawler` IAM role | Reads account assets, commitments, and service quotas |
| Feedback loop IAM role | Allows EventBridge to forward events cross-account to CXM |

---

## Section 3: Deploy to a Single OU

**What this does:** Builds on [Section 1](#section-1-organization-foundation) by deploying CXM asset crawler roles to member accounts within a **specific Organizational Unit** via CloudFormation StackSets.

> **Prerequisite:** Complete [Section 1](#section-1-organization-foundation) first.

### Step 1: Find your OU ID

```bash
# List root ID
aws organizations list-roots --profile org-root --query 'Roots[0].Id' --output text

# List OUs under the root (replace r-xxxx with your root ID)
aws organizations list-organizational-units-for-parent \
  --parent-id r-xxxx \
  --profile org-root \
  --query 'OrganizationalUnits[*].[Id,Name]' \
  --output table
```

Your OU ID will look like `ou-xxxx-xxxxxxxx`.

### Step 2: Add deployment_targets to your module

Update the `main.tf` from Section 1 to include `deployment_targets`:

```hcl
module "cxm_integration" {
  source  = "cxmlabs/cxm-integration/aws"
  version = "0.4.2"

  providers = {
    aws.root       = aws.root
    aws.cur        = aws.cur
    aws.cloudtrail = aws.root  # Not used — CloudTrail analysis is disabled below
    aws.flowlogs   = aws.root  # Not used — Flow Logs analysis is disabled by default
  }

  cxm_aws_account_id = "REPLACE_WITH_CXM_ACCOUNT_ID"
  cxm_external_id    = "REPLACE_WITH_CXM_EXTERNAL_ID"

  cost_usage_report_bucket_name = "REPLACE_WITH_CUR_BUCKET_NAME"
  disable_cloudtrail_analysis   = true

  # Deploy only to this specific OU
  deployment_targets = ["ou-xxxx-xxxxxxxx"]

  tags = {
    "ManagedBy" = "terraform"
    "Purpose"   = "cxm-integration"
  }
}
```

### Step 3: Apply

```bash
terraform plan
terraform apply
```

### Step 4: Verify your deployment

```bash
# Check StackSet status in the AWS Console or via CLI
aws cloudformation describe-stack-set \
  --stack-set-name cxm-account-enablement \
  --profile org-root \
  --call-as DELEGATED_ADMIN

# List stack instances
aws cloudformation list-stack-instances \
  --stack-set-name cxm-account-enablement \
  --profile org-root \
  --call-as DELEGATED_ADMIN \
  --query 'Summaries[*].[Account,Region,Status]' \
  --output table
```

Verify in member accounts:
- **IAM > Roles**: look for `cxm-asset-crawler`
- **EventBridge > Rules**: look for rules prefixed with `cxm`

### What was created (in each member account within the OU)

The StackSet deploys CloudFormation stacks into `us-east-1` in each member account. IAM roles are global and accessible from any region. EventBridge rules are created in `us-east-1`.

| Resource | Description |
|----------|-------------|
| `cxm-asset-crawler` IAM role | Read-only access to account assets, with commitment management permissions (global) |
| `cxm-feedback-loop-control-plane` IAM role | Allows EventBridge to forward CloudFormation events to CXM (global) |
| EventBridge rule | Notifies CXM of CloudFormation stack status changes (in `us-east-1`) |
| Explicit deny policy | Blocks data-plane access (Athena queries, DynamoDB reads, EC2 console, etc.) |

---

## Section 4: Full Organization Setup

**What this does:** Builds on [Section 1](#section-1-organization-foundation) by deploying CXM asset crawler roles to **all member accounts** across the entire Organization via CloudFormation StackSets.

> **Prerequisite:** Complete [Section 1](#section-1-organization-foundation) first.

### Step 1: Use deployment_targets with an empty list (default)

The default value of `deployment_targets` is `[]` (empty), which means the StackSet deploys to all OUs. You can simply omit the variable or set it explicitly:

```hcl
module "cxm_integration" {
  source  = "cxmlabs/cxm-integration/aws"
  version = "0.4.2"

  providers = {
    aws.root       = aws.root
    aws.cur        = aws.cur
    aws.cloudtrail = aws.root  # Not used — CloudTrail analysis is disabled below
    aws.flowlogs   = aws.root  # Not used — Flow Logs analysis is disabled by default
  }

  cxm_aws_account_id = "REPLACE_WITH_CXM_ACCOUNT_ID"
  cxm_external_id    = "REPLACE_WITH_CXM_EXTERNAL_ID"

  cost_usage_report_bucket_name = "REPLACE_WITH_CUR_BUCKET_NAME"
  disable_cloudtrail_analysis   = true

  # Deploy to ALL organizational units (this is the default)
  deployment_targets = []

  tags = {
    "ManagedBy" = "terraform"
    "Purpose"   = "cxm-integration"
  }
}
```

### Step 2: Apply

```bash
terraform plan
terraform apply
```

### Step 3: Verify your deployment

Use the same verification commands from [Section 3, Step 4](#step-4-verify-your-deployment).

### What was created (in every member account)

Same resources as [Section 3](#what-was-created-in-each-member-account-within-the-ou), but deployed across all accounts in the Organization.

> **Auto-deployment:** The StackSet uses `SERVICE_MANAGED` permissions with auto-deployment enabled. When new accounts are added to the Organization, they automatically receive the CXM roles.

---

## Bonus: EKS Cluster Enablement

**What this does:** Grants CXM read-only access to your EKS clusters. This is an optional add-on that works with any of the scenarios above.

The module automatically detects whether your cluster supports modern **EKS access entries** or requires the legacy **aws-auth ConfigMap** approach.

### Prerequisites

- [ ] CXM integration deployed (any section above)
- [ ] EKS cluster exists
- [ ] Kubernetes provider configured to authenticate with the cluster

### Step 1: Add the EKS enablement module

Add this alongside your existing CXM integration:

```hcl
data "aws_eks_cluster" "my_cluster" {
  name = "my-production-cluster"
}

data "aws_eks_cluster_auth" "my_cluster" {
  name = "my-production-cluster"
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.my_cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.my_cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.my_cluster.token
}

module "cxm_eks_enablement" {
  source = "cxmlabs/cxm-integration/aws//terraform-aws-eks-cluster-enablement"

  cluster_name = "my-production-cluster"
  iam_role_arn = module.cxm_integration.cxm_iam_role_name

  tags = {
    "ManagedBy" = "terraform"
    "Purpose"   = "cxm-eks-access"
  }
}
```

### Step 2: Apply

```bash
terraform init -upgrade  # Needed to fetch the EKS submodule
terraform plan
terraform apply
```

### Step 3: Verify

```bash
terraform output -module=cxm_eks_enablement
```

Check these outputs:
- `access_method` - Shows whether access entries or aws-auth ConfigMap was used
- `access_entry_created` - Should be `true` for modern clusters
- `aws_auth_configmap_updated` - Should be `true` for legacy clusters

### Namespace-scoped access (optional)

To restrict CXM to specific namespaces instead of cluster-wide access:

```hcl
module "cxm_eks_enablement" {
  source = "cxmlabs/cxm-integration/aws//terraform-aws-eks-cluster-enablement"

  cluster_name            = "my-production-cluster"
  iam_role_arn            = module.cxm_integration.cxm_iam_role_name
  access_scope_type       = "namespace"
  access_scope_namespaces = ["monitoring", "logging", "kube-system"]
}
```

---

## Enabling CloudTrail Analysis (Optional)

CloudTrail analysis lets CXM read your CloudTrail logs to provide deeper usage insights. It is **entirely optional** — the module works fully without it.

To enable it, make these changes to any section above:

### For Organization setups (Sections 1, 3, 4)

1. **Add a CloudTrail provider** to `provider.tf` — the region **must** match the CloudTrail S3 bucket's region:

```hcl
# Provider for the CloudTrail account — MUST be in the same region as the CloudTrail bucket
provider "aws" {
  region  = "us-east-2"        # <-- MUST match your CloudTrail bucket's region
  profile = "org-log-archive"  # <-- Change to your CloudTrail account profile
  alias   = "cloudtrail"
}
```

2. **Update the module** in `main.tf`:

```hcl
module "cxm_integration" {
  # ... same as before, but change these:

  providers = {
    aws.root       = aws.root
    aws.cur        = aws.cur
    aws.cloudtrail = aws.cloudtrail  # Point to the CloudTrail account
    aws.flowlogs   = aws.root       # Not used — Flow Logs analysis is disabled by default
  }

  # Remove disable_cloudtrail_analysis (or set to false)
  # Add the bucket name:
  cloudtrail_bucket_name = "REPLACE_WITH_CLOUDTRAIL_BUCKET_NAME"
}
```

### For Lone Account setups (Section 2)

Update the module in `main.tf`:

```hcl
module "cxm_integration" {
  # ... same as before, but change these:

  # Remove disable_cloudtrail_analysis (or set to false)
  # Add the bucket name:
  cloudtrail_bucket_name = "REPLACE_WITH_CLOUDTRAIL_BUCKET_NAME"
}
```

No provider changes needed — `aws.cloudtrail` already points to `aws` (same account).

### What gets created when CloudTrail is enabled

| Resource | Account | Description |
|----------|---------|-------------|
| `cxm-cloudtrail-reader` IAM role | CloudTrail account | Read-only access to the CloudTrail S3 bucket |
| EventBridge rules | CloudTrail account | Notifies CXM when new CloudTrail data arrives |
| Feedback loop IAM role | CloudTrail account | Allows EventBridge to forward events cross-account to CXM |

---

## Enabling VPC Flow Logs Analysis (Optional)

VPC Flow Logs analysis lets CXM read your centralized VPC Flow Logs from S3 to provide network traffic insights. It is **entirely optional** — the module works fully without it.

The Flow Logs S3 bucket can be in a **different AWS account and region** from your other resources.

To enable it, make these changes to any section above:

### For Organization setups (Sections 1, 3, 4)

1. **Add a Flow Logs provider** to `provider.tf` — the region **must** match the Flow Logs S3 bucket's region:

```hcl
# Provider for the Flow Logs account — MUST be in the same region as the Flow Logs bucket
provider "aws" {
  region  = "eu-west-1"        # <-- MUST match your Flow Logs bucket's region
  profile = "org-network-logs" # <-- Change to your Flow Logs account profile
  alias   = "flowlogs"
}
```

2. **Update the module** in `main.tf`:

```hcl
module "cxm_integration" {
  # ... same as before, but change these:

  providers = {
    aws.root       = aws.root
    aws.cur        = aws.cur
    aws.cloudtrail = aws.root       # Or aws.cloudtrail if CloudTrail is enabled
    aws.flowlogs   = aws.flowlogs   # Point to the Flow Logs account
  }

  # Enable Flow Logs analysis:
  disable_flowlogs_analysis = false
  flowlogs_bucket_name      = "REPLACE_WITH_FLOWLOGS_BUCKET_NAME"

  # Optional: if the Flow Logs bucket is encrypted with a KMS key
  # flowlogs_kms_key_arn = "arn:aws:kms:eu-west-1:123456789012:key/my-key-id"
}
```

### For Lone Account setups (Section 2)

Update the module in `main.tf`:

```hcl
module "cxm_integration" {
  # ... same as before, but change these:

  # Enable Flow Logs analysis:
  disable_flowlogs_analysis = false
  flowlogs_bucket_name      = "REPLACE_WITH_FLOWLOGS_BUCKET_NAME"
}
```

No provider changes needed — `aws.flowlogs` already points to `aws` (same account).

### What gets created when Flow Logs analysis is enabled

| Resource | Account | Description |
|----------|---------|-------------|
| `cxm-flowlogs-reader` IAM role | Flow Logs account | Read-only access to the Flow Logs S3 bucket |
| EventBridge rules | Flow Logs account | Notifies CXM when new Flow Logs data arrives |
| Feedback loop IAM role | Flow Logs account | Allows EventBridge to forward events cross-account to CXM |

---

## Optional Configuration

These variables can be added to any scenario above:

| Variable | Default | Description |
|----------|---------|-------------|
| `prefix` | `"cxm"` | Prefix for all resource names (e.g., role names become `{prefix}-organization-crawler`) |
| `role_suffix` | `null` | Suffix appended to role names (e.g., `-prod` makes `cxm-organization-crawler-prod`) |
| `permission_boundary_arn` | `null` | ARN of a permissions boundary policy to attach to all created IAM roles |
| `s3_kms_key_arn` | `null` | ARN of the KMS key used to encrypt CUR/CloudTrail data in S3 |
| `disable_asset_discovery` | `false` | Disable asset discovery (strongly discouraged) |
| `disable_cur_analysis` | `false` | Disable CUR analysis. Set to `true` when CUR is handled separately (e.g., lone account for metadata crawling only) |
| `cost_usage_report_bucket_name` | `null` | S3 bucket storing CUR data (required when CUR analysis is enabled) |
| `disable_cloudtrail_analysis` | `false` | Disable CloudTrail analysis (see [Enabling CloudTrail Analysis](#enabling-cloudtrail-analysis-optional)) |
| `cloudtrail_bucket_name` | `null` | S3 bucket storing CloudTrail logs (required when CloudTrail analysis is enabled) |
| `disable_flowlogs_analysis` | `true` | Disable VPC Flow Logs analysis (see [Enabling Flow Logs Analysis](#enabling-vpc-flow-logs-analysis-optional)) |
| `flowlogs_bucket_name` | `null` | S3 bucket storing centralized VPC Flow Logs (required when Flow Logs analysis is enabled) |
| `flowlogs_kms_key_arn` | `null` | KMS key ARN for encrypted Flow Logs data in S3 |
| `enable_scheduling` | `false` | Enable scheduling and scaling permissions for FinOps cost optimization |
### Example with optional variables

```hcl
module "cxm_integration" {
  source  = "cxmlabs/cxm-integration/aws"
  version = "0.4.2"

  providers = {
    aws.root       = aws.root
    aws.cur        = aws.cur
    aws.cloudtrail = aws.root  # Not used when disable_cloudtrail_analysis = true
    aws.flowlogs   = aws.root  # Not used — Flow Logs analysis is disabled by default
  }

  cxm_aws_account_id = "REPLACE_WITH_CXM_ACCOUNT_ID"
  cxm_external_id    = "REPLACE_WITH_CXM_EXTERNAL_ID"

  cost_usage_report_bucket_name = "my-cur-bucket"
  disable_cloudtrail_analysis   = true

  # Optional configuration
  prefix                  = "mycompany-cxm"
  role_suffix             = "prod"
  permission_boundary_arn = "arn:aws:iam::123456789012:policy/my-boundary"
  s3_kms_key_arn          = "arn:aws:kms:us-east-1:123456789012:key/my-key-id"

  tags = {
    "ManagedBy"   = "terraform"
    "Environment" = "production"
  }
}
```

> **Note on `enable_scheduling`:** When set to `true`, the module creates an additional IAM policy granting stop/start/scale permissions for EC2, RDS, ECS, EKS, ASG, Lambda, ElastiCache, Redshift, and SageMaker. Disabled by default — set to `true` to enable FinOps scheduling capabilities.

---

## Upgrading

### Upgrading to 1.0.0

This version introduces **breaking changes**:

**1. Benchmarking module removed**

The `enable_benchmarking` variable and `aws.benchmarking` provider alias have been removed. If you were using benchmarking, follow this upgrade sequence:

```hcl
# Step 1: Disable benchmarking BEFORE upgrading (on your current version)
enable_benchmarking = false
```

```bash
# Step 2: Apply to destroy benchmarking resources cleanly
terraform apply
```

```hcl
# Step 3: Upgrade module version and remove the aws.benchmarking provider alias
module "cxm_integration" {
  source  = "cxmlabs/cxm-integration/aws"
  version = "1.0.0"

  providers = {
    aws.root       = aws.root
    aws.cur        = aws.cur
    aws.cloudtrail = aws.cloudtrail
    # aws.benchmarking removed — delete this line
  }

  # enable_benchmarking removed — delete this line
}
```

```bash
# Step 4: Apply
terraform apply
```

> **Warning:** If you remove the `aws.benchmarking` provider alias before disabling benchmarking, existing benchmarking resources will become orphaned in your Terraform state and cannot be cleanly destroyed.

**2. New `enable_scheduling` variable**

A new opt-in variable `enable_scheduling` (default: `false`) is available. Set to `true` to grant CXM stop/start/scale permissions for FinOps cost optimization.
