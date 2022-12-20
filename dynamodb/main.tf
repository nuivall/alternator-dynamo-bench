terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

resource "aws_dynamodb_table" "basic-dynamodb-table" {
  name     = "usertable"
  hash_key = "p"
  attribute {
    name = "p"
    type = "S"
  }

  billing_mode   = "PROVISIONED"
  read_capacity  = 20
  write_capacity = 20

  tags = {
    Owner = "Benchmarking"
  }
}