# In-place query access (resource policy).
#
# Athena reads S3 as the principal that submitted the query and cannot be handed an
# assumed-role session, so the identity policy in main.tf never applies to the scan path.
# A resource policy on the bucket (and on the KMS key, when the bucket is encrypted) is
# the only grant that works. The principal is account-delegated and narrowed by object
# prefix, never by role name: submitting roles are named per tenant and per service, so
# naming them would break the policy on any rename.

locals {
  inplace_object_prefix = "${trimsuffix(var.inplace_query_object_prefix, "/")}/"
  inplace_bucket_arn    = "arn:aws:s3:::${var.s3_bucket_name}"
  inplace_kms_statement = var.s3_bucket_kms_key_arn != null || var.manage_kms_key_policy

  # One statement per reader account, with the account id in the Sid. A bucket read by
  # several CXM tenants gets one statement set each. The suffix is what makes them mergeable:
  # aws_iam_policy_document rejects a duplicate Sid outright ("Remove the Sid or ensure Sids
  # are unique"), and while PutBucketPolicy does accept duplicates, two statements sharing a
  # Sid cannot be told apart afterwards — so one reader's grant could not be updated or
  # revoked without touching the other's.
  inplace_reader_accounts = distinct(concat(
    [var.cxm_aws_account_id],
    [for reader in var.additional_cxm_readers : reader.account_id],
  ))
}

# Three separate statements are mandatory: s3:GetBucketLocation does not support the
# s3:prefix condition key, so folding it in with s3:ListBucket is rejected as
# MalformedPolicy — and a rejected PutBucketPolicy leaves the previous policy live.
# Do NOT add an aws:CalledVia condition here: Athena does not populate CalledVia on its
# scan requests, so the condition denies Athena itself.
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

# The identity-policy kms:Decrypt in main.tf does not substitute for a key policy: the
# query submitter is not the role that identity policy is attached to.
# kms:GenerateDataKey is write-side only and deliberately excluded.
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

# Opt-in ownership of the bucket policy. Only ever safe on a bucket dedicated to this
# integration: aws_s3_bucket_policy replaces the whole policy, and log buckets always
# carry AWS log-delivery statements that must survive.
data "aws_s3_bucket_policy" "existing" {
  count  = var.manage_bucket_policy && var.merge_existing_bucket_policy ? 1 : 0
  bucket = var.s3_bucket_name
}

# Our statements go in override_policy_documents, not source: the second apply reads back a
# policy that already carries them, and source_policy_documents rejects a duplicate Sid
# outright ("duplicate Sid ... Remove the Sid or ensure Sids are unique"). override replaces
# a same-Sid statement instead, so re-applying is idempotent and anything else in the policy
# still survives.
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

# The AWS provider exposes no data source for an existing KMS key policy, so the current
# policy must be handed in explicitly. Replacing a key policy without its administrative
# statements locks the key permanently, hence the precondition rather than a silent default.
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
