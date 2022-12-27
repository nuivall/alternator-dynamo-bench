resource "aws_iam_role" "dynamo_role" {
  count = var.dynamo_testing ? 1 : 0
  name               = "dynamo_role"
  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"]
  assume_role_policy = data.aws_iam_policy_document.dynamo_policy.json
}

resource "aws_iam_instance_profile" "dynamo_profile" {
  count = var.dynamo_testing ? 1 : 0
  name = "dynamo_profile"
  role = aws_iam_role.dynamo_role[count.index].name
}

data "aws_iam_policy_document" "dynamo_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_dynamodb_table" "basic-dynamodb-table" {
  count = var.dynamo_testing ? 1 : 0
  name     = "usertable"
  hash_key = "p"
  attribute {
    name = "p"
    type = "S"
  }

  billing_mode   = "PROVISIONED"
  read_capacity  = 1000
  write_capacity = 1000
}