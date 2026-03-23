data "aws_region" "root" {
  provider = aws.root
}

data "aws_caller_identity" "root" {
  provider = aws.root
}

data "aws_region" "cur" {
  provider = aws.cur
}

data "aws_caller_identity" "cur" {
  provider = aws.cur
}

data "aws_region" "cloudtrail" {
  provider = aws.cloudtrail
}

data "aws_caller_identity" "cloudtrail" {
  provider = aws.cloudtrail
}

data "aws_region" "flowlogs" {
  provider = aws.flowlogs
}

data "aws_caller_identity" "flowlogs" {
  provider = aws.flowlogs
}
