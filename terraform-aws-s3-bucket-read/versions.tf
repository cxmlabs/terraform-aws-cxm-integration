terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.74.0"
      # aws.kms owns the in-place KMS key policy, which for a log bucket lives in a different
      # account than the bucket. Map it to the bucket's provider where they share an account.
      configuration_aliases = [aws.kms]
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 2.1"
    }
  }
}
