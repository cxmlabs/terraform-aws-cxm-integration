# Basic CXM EKS Cluster Enablement Example

This example demonstrates how to use the `terraform-aws-eks-cluster-enablement` module to enable Cloud ex Machina (CXM) access to an existing EKS cluster.

## Prerequisites

1. An existing EKS cluster
2. AWS CLI configured with appropriate permissions
3. kubectl configured to access the EKS cluster
4. Terraform >= 1.0 installed

## Usage

1. Copy this example to a new directory:
   ```bash
   cp -r examples/basic my-eks-enablement
   cd my-eks-enablement
   ```

2. Create a `terraform.tfvars` file with your specific values:
   ```hcl
   aws_region         = "us-west-2"
   cluster_name       = "my-production-cluster"
   cxm_aws_account_id = "123456789012"  # Replace with actual CXM account ID
   cxm_external_id    = "your-unique-external-id"

   # Optional: Configure namespace-scoped access
   # access_scope_type = "namespace"
   # access_scope_namespaces = ["monitoring", "logging"]

   tags = {
     Environment = "production"
     Team        = "platform"
     Project     = "cxm-integration"
   }
   ```

3. Initialize and apply Terraform:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## What This Example Does

1. **CXM Integration**: Enables CXM access using the main `terraform-aws-cxm-integration` module (automatically handles account or organization deployment)
2. **EKS Configuration**: Configures the EKS cluster to allow the CXM role to access cluster resources
3. **Access Method**: Automatically chooses between modern access entries or legacy aws-auth ConfigMap based on cluster capabilities

## Expected Outputs

After successful deployment, you'll see outputs including:

- `cluster_name`: The name of your EKS cluster
- `access_method`: Whether "access_entries" or "aws_auth_configmap" was used
- `cluster_supports_access_entries`: Boolean indicating native access entry support
- `iam_role_arn`: ARN of the created CXM IAM role

## Verification

You can verify the configuration by checking:

### For Access Entries (Modern Clusters)
```bash
aws eks list-access-entries --cluster-name your-cluster-name
aws eks describe-access-entry --cluster-name your-cluster-name --principal-arn arn:aws:iam::ACCOUNT:role/cxm-asset-crawler
```

### For aws-auth ConfigMap (Legacy Clusters)
```bash
kubectl get configmap aws-auth -n kube-system -o yaml
```

## Cleanup

To remove the CXM access configuration:

```bash
terraform destroy
```

Note: This will remove the CXM IAM role and access configuration but will not affect your EKS cluster itself.
