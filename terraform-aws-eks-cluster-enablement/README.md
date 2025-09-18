# Terraform AWS EKS Cluster Enablement Module

This Terraform module enables Cloud ex Machina (CXM) access to AWS EKS clusters by configuring the appropriate authentication and authorization mechanisms. The module automatically detects whether the cluster supports modern EKS access entries or requires the legacy aws-auth ConfigMap approach.

## Features

- **Automatic Detection**: Detects whether the EKS cluster supports access entries or requires legacy aws-auth ConfigMap
- **Modern Access Entries**: Uses AWS EKS access entries with policy associations for supported clusters
- **Legacy Support**: Falls back to aws-auth ConfigMap for older clusters
- **Flexible Configuration**: Supports both cluster-wide and namespace-scoped access
- **Upgrade Path**: Provides instructions for manually upgrading legacy clusters to support access entries

## Prerequisites

- EKS cluster must exist
- IAM role must be created by one of the CXM enablement modules:
  - `terraform-aws-account-enablement`
  - `terraform-aws-organization-enablement`
  - `terraform-aws-full-organization-enablement`
- Kubernetes provider must be configured to authenticate with the EKS cluster

## Usage

### Basic Usage with CXM Integration Module

```hcl
# First, enable CXM on the account/organization
module "cxm_integration" {
  source  = "cxmlabs/cxm-integration/aws"
  version = "0.1.0"

  cxm_aws_account_id = "123456789012"
  cxm_external_id    = "your-external-id"

}

# Then, enable CXM access to EKS cluster
module "cxm_eks_enablement" {
  source = "./terraform-aws-eks-cluster-enablement"

  cluster_name = "my-production-cluster"
  iam_role_arn = module.cxm_integration.cxm_iam_role_arn

  # Module automatically detects and uses appropriate access method

  tags = {
    Environment = "production"
    Team        = "platform"
  }
}
```

### Advanced Usage with Namespace Scoping

```hcl
module "cxm_eks_enablement" {
  source = "./terraform-aws-eks-cluster-enablement"

  cluster_name   = "my-cluster"
  iam_role_arn   = "arn:aws:iam::123456789012:role/cxm-asset-crawler"

  # Scope access to specific namespaces
  access_scope_type       = "namespace"
  access_scope_namespaces = ["monitoring", "logging", "kube-system"]

  tags = {
    Environment = "staging"
  }
}
```

### Legacy Cluster with aws-auth ConfigMap

```hcl
module "cxm_eks_enablement" {
  source = "./terraform-aws-eks-cluster-enablement"

  cluster_name   = "legacy-cluster"
  iam_role_arn   = "arn:aws:iam::123456789012:role/cxm-asset-crawler"

  # For legacy clusters, module automatically uses aws-auth ConfigMap
  # Specify Kubernetes groups for RBAC
  kubernetes_groups = ["system:masters"]

  tags = {
    Environment = "legacy"
  }
}
```

### Upgrading Legacy Cluster to Access Entries

To upgrade a legacy cluster to use access entries, run this AWS CLI command first:

```bash
aws eks update-cluster-config \
  --name legacy-cluster \
  --access-config authenticationMode=API_AND_CONFIG_MAP
```

Then re-run Terraform - the module will automatically detect the new capability and switch to access entries.

## Authentication Methods

### Access Entries (Modern)
For clusters that support access entries (EKS API version 2023-10-14 or later), the module will:
1. Create an EKS access entry for the CXM IAM role
2. Associate the `AmazonEKSViewPolicy` with cluster or namespace scope
3. Grant read-only access to cluster resources

### aws-auth ConfigMap (Legacy)
For older clusters that don't support access entries, the module will:
1. Update the existing aws-auth ConfigMap in the kube-system namespace
2. Add the CXM IAM role mapping to the specified Kubernetes groups
3. Preserve existing role mappings

### Upgrade Path
To upgrade a legacy cluster to use access entries:
1. Run the AWS CLI command: `aws eks update-cluster-config --name CLUSTER_NAME --access-config authenticationMode=API_AND_CONFIG_MAP`
2. Re-run Terraform - the module will automatically detect the new capability and switch to access entries

<!-- BEGIN_TF_DOCS -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| cluster_name | Name of the EKS cluster to configure access for | `string` | n/a | yes |
| iam_role_arn | ARN or name of the IAM role created by the CXM account enablement module | `string` | n/a | yes |
| kubernetes_groups | List of Kubernetes groups to assign to the IAM role (aws-auth ConfigMap only) | `list(string)` | `[]` | no |
| access_scope_type | Type of access scope for the policy association ('cluster' or 'namespace') | `string` | `"cluster"` | no |
| access_scope_namespaces | List of namespaces for the access scope when type is 'namespace' | `list(string)` | `[]` | no |
| tags | A map/dictionary of Tags to be assigned to created resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster_name | Name of the EKS cluster that was configured |
| cluster_endpoint | Endpoint URL of the EKS cluster |
| cluster_account_id | ID of the AWS Account where the cluster is |
| cluster_supports_access_entries | Whether the cluster natively supports access entries |
| access_entry_created | Whether an access entry was created for the CXM role |
| policy_association_created | Whether a policy association was created for the CXM role |
| aws_auth_configmap_updated | Whether the aws-auth ConfigMap was updated (for legacy clusters) |
| iam_role_arn | ARN of the IAM role that was granted access to the cluster |
| access_method | Method used to grant access to the cluster (access_entries or aws_auth_configmap) |

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 5.0 |
| kubernetes | >= 2.20 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 5.0 |
| kubernetes | >= 2.20 |
<!-- END_TF_DOCS -->

## Permissions

The module requires the following permissions:

### AWS Provider
- `eks:DescribeCluster`
- `eks:UpdateCluster` (if upgrading legacy clusters)
- `eks:CreateAccessEntry`
- `eks:AssociateAccessPolicy`
- `iam:GetRole`

### Kubernetes Provider
- Access to read and update ConfigMaps in the kube-system namespace (for legacy clusters)

## Notes

- The module automatically detects the cluster's access entry support by checking the `access_config` block
- When upgrading legacy clusters, the authentication mode is set to `API_AND_CONFIG_MAP` to maintain backward compatibility
- The `AmazonEKSViewPolicy` provides read-only access to cluster resources
- For namespace-scoped access, ensure the specified namespaces exist in the cluster
- The module preserves existing aws-auth ConfigMap entries when updating legacy clusters

## Examples

### Basic Usage
See the [basic example](./examples/basic) for simple single-account, single-cluster setup.

### Advanced Organization-Wide Deployment
See the [organization multi-cluster example](./examples/organization-multi-cluster) for enterprise-scale deployment across multiple AWS accounts and EKS clusters within an AWS Organization.

**Advanced Example Features:**
- Multi-account EKS cluster access (Production + Staging)
- Different access patterns per environment (cluster-wide vs namespace-scoped)
- Cross-account role for centralized access management
- CloudWatch monitoring and compliance features
- Per-cluster customization options
