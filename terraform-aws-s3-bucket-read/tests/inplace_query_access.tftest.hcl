# Guards the two failure modes that would hurt a customer: emitting a grant Athena cannot
# use, and replacing a log bucket's policy instead of merging into it.

provider "aws" {
  region                      = "eu-west-1"
  access_key                  = "mock"
  secret_key                  = "mock"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
}

variables {
  cxm_aws_account_id    = "000000000000"
  iam_role_external_id  = "example-external-id"
  s3_bucket_name        = "example-log-bucket"
  s3_bucket_kms_key_arn = "arn:aws:kms:eu-west-1:000000000000:key/00000000-0000-0000-0000-000000000000"
}

run "default_mode_emits_statements_without_owning_the_policy" {
  command = plan

  assert {
    condition     = length(aws_s3_bucket_policy.cxm_inplace) == 0
    error_message = "Default mode must not take ownership of the bucket policy."
  }

  assert {
    condition     = length(aws_kms_key_policy.cxm_inplace) == 0
    error_message = "Default mode must not take ownership of the KMS key policy."
  }

  assert {
    condition = [
      for statement in jsondecode(output.inplace_query_bucket_policy_statements_json).Statement : statement.Sid
    ] == ["CxMInPlaceGetObject", "CxMInPlaceListBucket", "CxMInPlaceGetBucketLocation"]
    error_message = "The grant must stay three separate statements: s3:GetBucketLocation rejects the s3:prefix condition."
  }

  assert {
    condition = [
      for statement in jsondecode(output.inplace_query_bucket_policy_statements_json).Statement :
      statement.Condition.StringLike["s3:prefix"] if statement.Sid == "CxMInPlaceListBucket"
    ] == ["AWSLogs/*"]
    error_message = "s3:ListBucket must be narrowed by the s3:prefix condition."
  }

  assert {
    condition = alltrue([
      for statement in jsondecode(output.inplace_query_bucket_policy_statements_json).Statement :
      statement.Principal.AWS == "arn:aws:iam::000000000000:root"
    ])
    error_message = "The principal must be the CXM account, not a named role."
  }

  assert {
    condition     = !strcontains(output.inplace_query_bucket_policy_statements_json, "CalledVia")
    error_message = "aws:CalledVia denies Athena: it does not populate that key on scan requests."
  }

  assert {
    condition = jsondecode(output.inplace_query_kms_key_policy_statement_json).Statement[0].Action == [
      "kms:DescribeKey", "kms:Decrypt"
    ]
    error_message = "The KMS statement must grant exactly decrypt and describe; GenerateDataKey is write-side only."
  }
}

run "merge_mode_preserves_the_log_delivery_statement" {
  command = plan

  variables {
    manage_bucket_policy = true
  }

  override_data {
    target = data.aws_s3_bucket_policy.existing[0]
    values = {
      policy = <<-JSON
        {
          "Version": "2012-10-17",
          "Statement": [
            {
              "Sid": "AWSLogDeliveryWrite",
              "Effect": "Allow",
              "Principal": {"Service": "delivery.logs.amazonaws.com"},
              "Action": "s3:PutObject",
              "Resource": "arn:aws:s3:::example-log-bucket/AWSLogs/*"
            }
          ]
        }
      JSON
    }
  }

  assert {
    condition = contains([
      for statement in jsondecode(aws_s3_bucket_policy.cxm_inplace[0].policy).Statement : statement.Sid
    ], "AWSLogDeliveryWrite")
    error_message = "Merge mode dropped the pre-existing log-delivery statement."
  }

  assert {
    condition = length([
      for statement in jsondecode(aws_s3_bucket_policy.cxm_inplace[0].policy).Statement : statement.Sid
    ]) == 4
    error_message = "Merge mode must add the three CXM statements to the existing one."
  }
}
