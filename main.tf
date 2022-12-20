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
  region                   = "us-east-1"
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
  instance_type = "t2.micro"
  key_name = random_string.key_name.result

  count = var.loader_instances_count

  availability_zone = element(var.loader_avaliability_zones, count.index)

  tags = {
    Name = "Loader"
    Owner = "Benchmarking"
  }
}

# This runs provisioning steps
resource "null_resource" "loader" {
  # Changes to any instance requires re-provisioning
  triggers = {
    loader_instance_ids = join(",", aws_instance.loader.*.id)
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

  # Copy opt directory containing executables
	provisioner "file" {
    source = "scylla/"
		destination = "/opt/scylla"
	}

}
