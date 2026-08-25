# Athena reads S3 as the query submitter, not the assumed role, so only a resource policy
# works. Principal is the account, narrowed by prefix: role names change, accounts do not.

locals {
  inplace_object_prefix = "${trimsuffix(var.inplace_query_object_prefix, "/")}/"
  inplace_bucket_arn    = "arn:aws:s3:::${var.s3_bucket_name}"
  inplace_kms_statement = var.s3_bucket_kms_key_arn != null || var.manage_kms_key_policy

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

# The reader role's kms:Decrypt does not cover the query submitter. GenerateDataKey is
# write-side only, so it stays out.
data "aws_iam_policy_document" "cxm_inplace_kms_statement" {
  count   = local.inplace_kms_statement ? 1 : 0
  version = "2012-10-17"

  dynamic "statement" {
    for_each = local.inplace_reader_accounts

    content {
      sid       = "CxMInPlaceDecrypt${statement.value}"
      actions   = ["kms:Decrypt", "kms:DescribeKey"]
      resources = ["*"]

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

# No data source exists for a key policy, so it is handed in. Replacing one without its
# admin statements locks the key for good — hence the precondition.
data "aws_iam_policy_document" "cxm_inplace_kms_key_policy" {
  count   = var.manage_kms_key_policy ? 1 : 0
  version = "2012-10-17"

  source_policy_documents   = [var.existing_kms_key_policy_json]
  override_policy_documents = [data.aws_iam_policy_document.cxm_inplace_kms_statement[0].json]
}

resource "aws_kms_key_policy" "cxm_inplace" {
  count  = var.manage_kms_key_policy ? 1 : 0
  key_id = var.s3_bucket_kms_key_arn
  policy = data.aws_iam_policy_document.cxm_inplace_kms_key_policy[count.index].json

  lifecycle {
    precondition {
      condition     = var.s3_bucket_kms_key_arn != null && var.existing_kms_key_policy_json != null
      error_message = "manage_kms_key_policy requires both s3_bucket_kms_key_arn and existing_kms_key_policy_json: the current key policy must be merged in, or the key becomes unmanageable."
    }
  }
}
