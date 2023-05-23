terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
    # For now not published in the registry, see create-tf-rc-file.sh.
    scylladbcloud = {
      source  = "registry.terraform.io/scylladb/scylladbcloud"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region                   = var.aws_region
  shared_credentials_files = ["$HOME/.aws/credentials"]
  default_tags {
    tags = {
      Owner = "Benchmarking"
      RunByUser = "Benchmarking"
    }
  }
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

# This is the VPC for loaders
resource "aws_vpc" "loader_vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
}

resource "aws_internet_gateway" "loader_igw" {
	vpc_id = aws_vpc.loader_vpc.id
}

resource "aws_route_table" "main_rt" {
	vpc_id = aws_vpc.loader_vpc.id
}

resource "aws_route" "internet_rt" {
  route_table_id            = aws_route_table.main_rt.id
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.loader_igw.id
}

resource "aws_security_group" "public_sg" {
  name = "benchmarking-sg-${random_string.key_name.result}"
  description = "Allows to reach loaders from the Internet"
  vpc_id      = aws_vpc.loader_vpc.id

  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # depends_on = [
  #   aws_vpc.loader_vpc
  # ]
}

# Subnet for each loader (needs to be per AZ)
resource "aws_subnet" "loader_subnet" {
  cidr_block = format("10.0.%d.0/24", count.index)
  availability_zone = element(var.loader_avaliability_zones, count.index)
  vpc_id = aws_vpc.loader_vpc.id
  map_public_ip_on_launch = true # auto assigns public IPs, needed to be able to SSH to the loader instances

  count = var.loader_instances_count
  depends_on = [aws_internet_gateway.loader_igw]
}

# This links route table to subnet
resource "aws_route_table_association" "main_rt_assoc" {
	route_table_id = aws_route_table.main_rt.id
	subnet_id = element(aws_subnet.loader_subnet.*.id, count.index)

	count = var.loader_instances_count
}

# Instances which run ycsb
resource "aws_instance" "loader" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.loader_instance_type
  key_name = random_string.key_name.result

  subnet_id = element(aws_subnet.loader_subnet.*.id, count.index)
  vpc_security_group_ids = [aws_security_group.public_sg.id]

  count = var.loader_instances_count

  tags = {
    Name = "Loader"
    NodeType = "loader"
  }

  iam_instance_profile = var.dynamo_testing ? aws_iam_instance_profile.dynamo_profile[0].name : null
}

# This runs provisioning steps
resource "null_resource" "loader" {
  # Changes to any instance requires re-provisioning
  triggers = {
    loader_instance_ids = join(",", aws_instance.loader.*.id)
    # Use code below to force recreating null_resource
    always_run = "${timestamp()}"
  }

  count = var.loader_instances_count

  connection {
    type = "ssh"
    host = element(aws_instance.loader.*.public_ip, count.index)
    user = "ubuntu"
    private_key = tls_private_key.ssh_key.private_key_openssh
    timeout = "1m"
  }

  # Make ubuntu user owning our binaries
  provisioner "remote-exec" {
    inline = [
      "sudo mkdir /opt/scylla",
      "sudo chown ubuntu /opt/scylla",
    ]
  }

  # Install dependecies needed for ycsb
	provisioner "file" {
    source = "opt/deps.sh"
		destination = "/opt/scylla/deps.sh"
	}

  provisioner "remote-exec" {
    inline = [
      "sudo bash -C /opt/scylla/deps.sh"
    ]
  }

  # Copy opt directory containing executables
	provisioner "file" {
    source = "opt/"
		destination = "/opt/scylla"
	}
}
