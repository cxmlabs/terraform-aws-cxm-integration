# Guards the two failure modes of the optional org restriction on the admin trust:
# silently dropping the restriction when it was asked for, and adding a condition
# that was never asked for (which would lock CxM out of the account).

provider "aws" {
  region                      = "eu-west-1"
  access_key                  = "mock"
  secret_key                  = "mock"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
}

variables {
  cxm_aws_account_id = "000000000000"
  cxm_external_id    = "example-external-id"
  cxm_admin_role_arn = "arn:aws:iam::000000000000:role/cxm-organization-crawler"
}

run "unset_org_id_leaves_the_admin_trust_unconditional" {
  command = plan

  assert {
    condition = length([
      for statement in jsondecode(data.aws_iam_policy_document.asset_crawler_assume_role_policy.json).Statement :
      statement if contains(keys(statement), "Condition") && contains(keys(statement.Condition.StringEquals), "aws:PrincipalOrgID")
    ]) == 0
    error_message = "No org restriction was requested, so aws:PrincipalOrgID must not appear."
  }
}

run "set_org_id_restricts_the_admin_trust_to_that_org" {
  command = plan

  variables {
    xacct_assume_role_org_id = "o-example12345"
  }

  assert {
    condition = [
      for statement in jsondecode(data.aws_iam_policy_document.asset_crawler_assume_role_policy.json).Statement :
      statement.Condition.StringEquals["aws:PrincipalOrgID"]
      if contains(keys(statement), "Condition") && contains(keys(statement.Condition.StringEquals), "aws:PrincipalOrgID")
    ] == ["o-example12345"]
    error_message = "The admin (AWS principal) statement must carry aws:PrincipalOrgID when an org ID is set."
  }

  assert {
    condition = [
      for statement in jsondecode(data.aws_iam_policy_document.asset_crawler_assume_role_policy.json).Statement :
      statement.Principal.AWS
      if contains(keys(statement), "Condition") && contains(keys(statement.Condition.StringEquals), "aws:PrincipalOrgID")
    ] == ["arn:aws:iam::000000000000:role/cxm-organization-crawler"]
    error_message = "The org restriction must land on the admin-role statement, not the service-principal statement."
  }
}
