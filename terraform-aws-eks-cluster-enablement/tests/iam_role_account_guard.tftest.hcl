# Guards the failure mode that silently breaks a customer's EKS crawl: an iam_role_arn from a
# different account than the cluster's. The role is always resolved by NAME in this module's
# provider account, so a foreign ARN either resolves a same-named local role or fails with a
# confusing "not found" - and the access entry ends up naming the wrong principal.
#
# The bare-name run also pins a regression: the guard's error_message is evaluated eagerly by
# Terraform even when the condition passes, so interpolating the null account id there fails
# every plan that supplies a bare role name. Do not remove the coalesce in main.tf.
#
# The providers are mocked so the plan is hermetic: no credentials, no network, and a caller
# identity we control so the guard can be exercised deterministically.

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "111111111111"
    }
  }

  mock_data "aws_eks_cluster" {
    defaults = {
      arn      = "arn:aws:eks:eu-west-1:111111111111:cluster/example-cluster"
      endpoint = "https://example.eks.eu-west-1.amazonaws.com"
      # Non-null authentication_mode is what makes the module take the access-entry path
      # instead of the legacy aws-auth ConfigMap path.
      access_config = [{
        authentication_mode                         = "API_AND_CONFIG_MAP"
        bootstrap_cluster_creator_admin_permissions = true
      }]
    }
  }

  mock_data "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::111111111111:role/cxm-asset-crawler"
    }
  }
}

mock_provider "kubernetes" {}

variables {
  cluster_name = "example-cluster"
  iam_role_arn = "cxm-asset-crawler"
}

run "bare_role_name_is_resolved_against_the_provider_account" {
  command = plan

  assert {
    condition     = length(aws_eks_access_entry.cxm_access_entry) == 1
    error_message = "A cluster advertising an authentication_mode must get an access entry, not an aws-auth ConfigMap edit."
  }

  assert {
    condition     = aws_eks_access_entry.cxm_access_entry[0].user_name == "cxm-asset-crawler"
    error_message = "A bare name must be used as-is when looking the role up in the cluster account."
  }

  assert {
    condition     = aws_eks_access_entry.cxm_access_entry[0].principal_arn == "arn:aws:iam::111111111111:role/cxm-asset-crawler"
    error_message = "The access entry must name the role resolved in the cluster's own account."
  }
}

run "arn_from_the_cluster_account_is_accepted_and_reduced_to_its_role_name" {
  command = plan

  variables {
    iam_role_arn = "arn:aws:iam::111111111111:role/cxm-asset-crawler"
  }

  assert {
    condition     = aws_eks_access_entry.cxm_access_entry[0].user_name == "cxm-asset-crawler"
    error_message = "An ARN must be reduced to its role name before the IAM lookup."
  }

  assert {
    condition     = aws_eks_access_entry.cxm_access_entry[0].principal_arn == "arn:aws:iam::111111111111:role/cxm-asset-crawler"
    error_message = "A same-account ARN must produce an access entry for that same role."
  }
}

run "arn_from_another_account_fails_the_plan" {
  command = plan

  variables {
    # Typically the management account's organization crawler, which only performs the first
    # assume-role hop and never reaches the Kubernetes API itself.
    iam_role_arn = "arn:aws:iam::222222222222:role/cxm-organization-crawler"
  }

  expect_failures = [terraform_data.iam_role_account_guard]
}
