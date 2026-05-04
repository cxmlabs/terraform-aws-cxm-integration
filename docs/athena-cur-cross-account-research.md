# Cross-Account Athena Access to CUR Data — Research & Design

## Context

CXM currently pulls customer CUR (Cost and Usage Report) data from their S3 bucket into our own database via the `terraform-aws-s3-bucket-read` module. This is costly and slow. We want to query CUR data directly using Athena + Glue, avoiding the full data transfer.

### Current Architecture

- This module deploys on **customer's AWS account**, granting CXM cross-account access
- Trust pattern: IAM role in customer account → trusts CXM AWS account via `sts:AssumeRole` + ExternalId
- CUR access: dedicated `cxm-cur-reader` role with `s3:ListBucket` + `s3:GetObject` on their CUR bucket
- Same `s3-bucket-read` submodule is reused for CloudTrail and VPC Flow Logs buckets
- Account crawler role explicitly **denies** `athena:StartQueryExecution` and `athena:StartCalculationExecution` (data-plane protection in `terraform-aws-account-enablement`)

## Options Evaluated

### Option A — Glue + Athena on CXM's Account (Recommended)

CXM runs all compute (Glue catalog, Athena queries) in its own AWS account, reading customer S3 cross-account.

**Customer-side changes (this module):**
- S3 bucket policy on CUR bucket granting CXM account direct read access (`s3:GetObject`, `s3:ListBucket`, `s3:GetBucketLocation`)
- Feature-flagged, opt-in (`enable_cross_account_s3_access` on `s3-bucket-read` submodule)
- Output the policy JSON so customers with existing bucket policies can merge manually
- If CUR bucket uses KMS: customer must also grant CXM account `kms:Decrypt` + `kms:GenerateDataKey` in their KMS key policy (separate from bucket policy, not automatable via this module without managing their key policy)

**CXM-side (separate infra, not this repo):**
- Glue Data Catalog: database + tables per customer, pointing to their CUR S3
- Athena workgroup (per customer or shared)
- Execution roles for Glue crawlers and Athena with cross-account S3 read
- S3 results bucket in CXM account

**Pros:**
- Minimal customer-side footprint — just bucket policy, no Glue/Athena permissions
- CXM controls all compute and catalog
- No billing surprise for customer (Athena data-scanned costs go to CXM)
- No conflict with existing `athena:StartQueryExecution` deny on crawler role
- Aligns with the module's philosophy: readonly, minimal impact

**Cons:**
- Cross-account S3 reads may be slower than local
- Bucket policy approach is different from existing AssumeRole+ExternalId trust model
- Customers with restrictive S3 bucket policies (VPC endpoint conditions, org restrictions) may need adjustments
- `aws_s3_bucket_policy` resource replaces the full policy — risky for buckets with existing policies (e.g., CUR delivery policy)

### Option B — Glue + Athena on Customer's Account

CXM assumes the cross-account role and runs everything in the customer's account.

**Customer-side changes:**
- Athena permissions on the CUR reader role: `athena:StartQueryExecution`, `athena:GetQueryExecution`, `athena:GetQueryResults`, `athena:StopQueryExecution`, `athena:GetWorkGroup` — scoped to `arn:aws:athena:*:*:workgroup/cxm-*`
- Glue catalog permissions: `glue:CreateDatabase`, `glue:GetDatabase`, `glue:CreateTable`, `glue:GetTable`, `glue:GetTables`, `glue:UpdateTable`, `glue:DeleteTable`, `glue:GetPartition(s)`, `glue:CreatePartition`, `glue:BatchCreatePartition`, etc. — scoped to `arn:aws:glue:*:*:database/cxm-*` and `arn:aws:glue:*:*:table/cxm-*/*`
- S3 write for Athena results: `s3:PutObject`, `s3:AbortMultipartUpload` — scoped to `s3://cur-bucket/cxm-athena-results/*`
- Athena workgroup creation: `athena:CreateWorkGroup`, `athena:UpdateWorkGroup`

**Pros:**
- S3 access is local — fastest scan performance
- No cross-account data transfer costs
- Works regardless of customer's bucket policy restrictions
- Uses existing AssumeRole+ExternalId trust model — no new trust mechanism

**Cons:**
- More permissions on customer account (Glue write, Athena execute, S3 write)
- Goes against the "readonly, minimal impact" philosophy
- Customer pays for Athena query compute (data scanned)

### Option C — Hybrid (Glue on CXM, Athena on Customer)

Glue catalog and crawlers on CXM side, but Athena queries execute on customer side via AssumeRole.

**Customer-side changes:**
- Athena query permissions only (no Glue) — scoped to `cxm-*` workgroup
- S3 write for results — scoped to `cxm-athena-results/*` prefix
- Bucket policy for CXM Glue crawlers to read S3 cross-account

**Pros:**
- CXM manages catalog centrally
- Athena uses existing AssumeRole pattern (CXM code assumes role, calls StartQueryExecution with assumed credentials)
- Customer doesn't need Glue permissions

**Cons:**
- Mixed model — some resources CXM-side, some customer-side
- Still need bucket policy for Glue crawlers
- Customer still pays Athena compute

## Principal Analysis

### Why Athena Can't Use the Existing AssumeRole Pattern Directly (Option A)

Athena is an async managed service. When `StartQueryExecution` is called, Athena accesses S3 using either:
1. **Caller's identity** — works if caller assumed the customer role, but Athena caches credentials at submission time
2. **Workgroup execution role** — must be in the same account as Athena, cannot chain-assume cross-account

**Athena has no service principal** (unlike `ecs-tasks.amazonaws.com`, `lambda.amazonaws.com`, `glue.amazonaws.com`). No `athena.amazonaws.com` trust policy trick exists for cross-account S3 reads.

This is why Option A requires a **bucket policy** instead of the AssumeRole pattern.

### Glue Has a Service Principal

`glue.amazonaws.com` — Glue crawlers and ETL jobs can assume roles. However, for cross-account S3 access from CXM's Glue, the Glue execution role (in CXM account) still needs either:
- Bucket policy on customer side granting the role S3 read, OR
- A mechanism to AssumeRole into the customer account (Glue doesn't chain-assume during crawls)

So bucket policy is needed for CXM-side Glue crawlers too.

## Decision

**Option A** — Glue + Athena on CXM side. Bucket policy on customer side for cross-account S3 read.

Rationale:
- Minimal permissions on customer account — read-only bucket policy, nothing more
- No Glue/Athena/write permissions on customer account
- Consistent with module philosophy
- CXM absorbs compute costs
- No conflict with existing deny statements

## Implementation Plan

### Phase 1 — Option A (bucket policy)

Changes to `terraform-aws-s3-bucket-read`:
1. Add `enable_cross_account_s3_access` variable (default `false`)
2. Add `aws_iam_policy_document` for cross-account bucket read policy
3. Add `aws_s3_bucket_policy` resource (feature-flagged)
4. Add `cross_account_bucket_policy_json` output for manual merge

Root module changes:
1. Add `enable_cur_cross_account_s3_access` variable
2. Pass to CUR `s3-bucket-read` module

**Open issue:** `aws_s3_bucket_policy` replaces the full bucket policy. CUR buckets typically have existing policies (for AWS CUR delivery). Customers must either let the module manage the policy (and include their existing statements) or merge manually using the output. Consider using `source_policy_documents` in `aws_iam_policy_document` to merge with existing policy.

**Open issue:** KMS-encrypted buckets need separate KMS key policy grants. Not automatable without managing customer's KMS key policy.

### Phase 2 — Hybrid additions (if needed later)

If cross-account Athena proves too slow or restricted:
1. Add Athena query permissions to CUR reader role (scoped to `cxm-*` workgroup)
2. Add S3 write permissions for Athena results (scoped to `cxm-athena-results/*` prefix)
3. No Glue permissions needed (stays on CXM side)
4. No changes to account-enablement deny list (CUR reader is a separate role)

### Applicable to All Bucket Types

The `enable_cross_account_s3_access` flag lives in the generic `s3-bucket-read` submodule. Same pattern works for CloudTrail and FlowLogs buckets if direct cross-account querying is needed later.
