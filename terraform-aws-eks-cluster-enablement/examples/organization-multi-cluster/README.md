# Organization Multi-Cluster EKS Enablement

This example demonstrates how to enable CXM access across multiple EKS clusters in different AWS accounts within an organization. It showcases enterprise-scale deployment patterns with different access levels per environment.

## Architecture

```
AWS Organization
├── Management Account
│   └── Organization Enablement (StackSets)
├── Production Account
│   ├── prod-cluster-us-west-2 (cluster-wide access)
│   └── prod-api-cluster (cluster-wide access)
└── Staging Account
    ├── staging-cluster (namespace-scoped)
    └── dev-cluster (namespace-scoped)
```

## Key Features

- **Organization-wide deployment** using StackSets to deploy CXM IAM roles
- **Multi-account EKS access** with different security models per environment
- **Production clusters**: Full cluster visibility for comprehensive monitoring
- **Staging clusters**: Namespace-scoped access for security isolation
- **Automatic detection** of modern vs legacy clusters (access entries vs aws-auth ConfigMap)

## Prerequisites

- AWS Organization with existing EKS clusters in member accounts
- Management account with organization admin and StackSets permissions
- kubectl configured for target clusters
- AWS CLI profiles for each account

## Usage

1. **Configure your environment:**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit with your account IDs, cluster names, and settings
   ```

2. **Set up AWS CLI profiles:**
   ```bash
   aws configure --profile management
   aws configure --profile production
   aws configure --profile staging
   ```

3. **Deploy organization enablement first:**
   ```bash
   terraform init
   terraform apply -target=module.cxm_organization_enablement
   ```

4. **Then deploy EKS enablement:**
   ```bash
   terraform apply
   ```

## What Gets Created

- **EKS access entries** for modern clusters (or aws-auth ConfigMap for legacy clusters)
- **Production access**: Cluster-wide read access for comprehensive monitoring
- **Staging access**: Namespace-scoped access (kube-system, monitoring, logging)
- **Cross-account role** for centralized access management

## Verification

```bash
# Verify EKS access entries
aws eks list-access-entries --cluster-name prod-cluster-us-west-2 --profile production
aws eks list-access-entries --cluster-name staging-cluster --profile staging

# Test cluster access
kubectl get nodes --as=cxm-asset-crawler
```

## Cleanup

```bash
# Remove EKS enablement first
terraform destroy -target=module.cxm_production_eks_enablement
terraform destroy -target=module.cxm_staging_eks_enablement

# Then remove organization enablement
terraform destroy
```
