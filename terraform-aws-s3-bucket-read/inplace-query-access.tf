# Athena reads S3 as the query submitter, not the assumed role, so only a resource policy
# works. Principal is the account, narrowed by prefix: role names change, accounts do not.

locals {
  inplace_object_prefix = "${trimsuffix(var.inplace_query_object_prefix, "/")}/"
  inplace_bucket_arn    = "arn:aws:s3:::${var.s3_bucket_name}"

  # Account id in the Sid: aws_iam_policy_document rejects duplicate Sids, and S3 accepts them
  # but then one reader's grant cannot be revoked without rewriting the other's.
  inplace_reader_accounts = distinct(concat(
    [var.cxm_aws_account_id],
    [for reader in var.additional_cxm_readers : reader.account_id],
  ))
}

# Keep the three statements split: GetBucketLocation rejects the s3:prefix condition key.
# No aws:CalledVia — Athena does not set it on scans, so the condition would deny Athena.
data "aws_iam_policy_document" "cxm_inplace_bucket_statements" {
  version = "2012-10-17"

  dynamic "statement" {
    for_each = local.inplace_reader_accounts

    content {
      sid       = "CxMInPlaceGetObject${statement.value}"
      actions   = ["s3:GetObject"]
      resources = ["${local.inplace_bucket_arn}/${local.inplace_object_prefix}*"]

      principals {
        type        = "AWS"
        identifiers = ["arn:aws:iam::${statement.value}:root"]
      }
    }
  }

  dynamic "statement" {
    for_each = local.inplace_reader_accounts

    content {
      sid       = "CxMInPlaceListBucket${statement.value}"
      actions   = ["s3:ListBucket"]
      resources = [local.inplace_bucket_arn]

      principals {
        type        = "AWS"
        identifiers = ["arn:aws:iam::${statement.value}:root"]
      }

      condition {
        test     = "StringLike"
        variable = "s3:prefix"
        values   = ["${local.inplace_object_prefix}*"]
      }
    }
  }

  dynamic "statement" {
    for_each = local.inplace_reader_accounts

    content {
      sid       = "CxMInPlaceGetBucketLocation${statement.value}"
      actions   = ["s3:GetBucketLocation"]
      resources = [local.inplace_bucket_arn]

      principals {
        type        = "AWS"
        identifiers = ["arn:aws:iam::${statement.value}:root"]
      }
    }
  }
}

# Opt-in only: aws_s3_bucket_policy replaces the whole policy, and log buckets carry
# AWS log-delivery statements that must survive.
data "aws_s3_bucket_policy" "existing" {
  count  = var.manage_bucket_policy && var.merge_existing_bucket_policy ? 1 : 0
  bucket = var.s3_bucket_name
}

# Ours go in override, not source: the second apply reads back a policy already carrying them
# and source rejects the duplicate Sid. override replaces it instead, so re-applying works.
data "aws_iam_policy_document" "cxm_inplace_bucket_policy" {
  count   = var.manage_bucket_policy ? 1 : 0
  version = "2012-10-17"

  source_policy_documents   = [for existing in data.aws_s3_bucket_policy.existing : existing.policy]
  override_policy_documents = [data.aws_iam_policy_document.cxm_inplace_bucket_statements.json]
}

resource "aws_s3_bucket_policy" "cxm_inplace" {
  count  = var.manage_bucket_policy ? 1 : 0
  bucket = var.s3_bucket_name
  policy = data.aws_iam_policy_document.cxm_inplace_bucket_policy[count.index].json
}

# A grant is additive: it gives each reader account Decrypt without reading or replacing the
# key policy, so the key's existing statements are left untouched. GenerateDataKey is
# write-side only, so it stays out. The reading account's own IAM narrows the actual use.
resource "aws_kms_grant" "cxm_inplace" {
  for_each = var.manage_kms_grant && var.s3_bucket_kms_key_arn != null ? toset(local.inplace_reader_accounts) : toset([])

  provider          = aws.kms
  name              = "cxm-inplace-decrypt-${each.value}"
  key_id            = var.s3_bucket_kms_key_arn
  grantee_principal = "arn:aws:iam::${each.value}:root"
  operations        = ["Decrypt", "DescribeKey"]
}
