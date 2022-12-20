terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region                   = var.aws_region
  shared_credentials_files = ["$HOME/.aws/credentials"]
}

# Name of the key pair containing private SSH key
resource "random_string" "key_name" {
  length = 16
  special = false
  lower  = true
}

# Generate a key
resource "tls_private_key" "ssh_key" {
  algorithm = "ED25519"
}

# Public key part uploaded to AWS
resource "aws_key_pair" "ssh_key_pair" {
  key_name   = random_string.key_name.result
  public_key = tls_private_key.ssh_key.public_key_openssh
}

# Private key part written locally to access the instances
resource "local_sensitive_file" "private_key" {
    content  = tls_private_key.ssh_key.private_key_openssh
    filename = "private_key"
}

# This selects the right AMI
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

# Instances which run ycsb
resource "aws_instance" "loader" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.loader_instance_type
  key_name = random_string.key_name.result

  count = var.loader_instances_count

  availability_zone = element(var.loader_avaliability_zones, count.index)

  tags = {
    Name = "Loader"
    Owner = "Benchmarking"
    NodeType = "loader"
  }

  iam_instance_profile = aws_iam_instance_profile.dynamo_profile.name
}

resource "aws_iam_role" "dynamo_role" {
  name               = "dynamo_role"
  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"]
  assume_role_policy = data.aws_iam_policy_document.dynamo_policy.json
}

resource "aws_iam_instance_profile" "dynamo_profile" {
  name = "dynamo_profile"
  role = aws_iam_role.dynamo_role.name
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

# This runs provisioning steps
resource "null_resource" "loader" {
  # Changes to any instance requires re-provisioning
  triggers = {
    loader_instance_ids = join(",", aws_instance.loader.*.id)
    # Use code below to force recreating null_resource
    # always_run = "${timestamp()}"
  }

  count = var.loader_instances_count

  connection {
    type = "ssh"
    host = element(aws_instance.loader.*.public_ip, count.index)
    user = "ubuntu"
    private_key = tls_private_key.ssh_key.private_key_openssh
    timeout = "30s"
  }

  # Make ubuntu user owning our binaries
  provisioner "remote-exec" {
    inline = [
      "sudo mkdir /opt/scylla",
      "sudo chown ubuntu /opt/scylla",
    ]
  }

  # Install dependecies needed for ycsb
  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install -y python2",
      "sudo ln -s /usr/bin/python2 /usr/bin/python",
      "sudo apt install -y default-jre"
    ]
  }

  # Copy opt directory containing executables
	provisioner "file" {
    source = "opt/"
		destination = "/opt/scylla"
	}

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