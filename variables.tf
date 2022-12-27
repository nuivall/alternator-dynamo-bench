variable "aws_region" {
	default = "us-east-1"
}

variable "loader_avaliability_zones" {
	description = ""
	type = list(string)
    # List using: aws ec2 describe-availability-zones --region="us-east-1"
	default = [
		"us-east-1a",
		"us-east-1b",
        "us-east-1c",
	]
}

variable "loader_instance_type" {
  default = "t3.micro"
}

variable "loader_instances_count" {
	default = 3
}

# This should be on when testing dynamoDB and off when testing scylla alternator.
variable "dynamo_testing" {
}

# Provisioned write capacity for dynamoDB.
variable "dynamo_wcu" {
	default = 1000
}

# Provisioned read capacity for dynamoDB.
variable "dynamo_rcu" {
	default = 1000
}

# This is API token for Scylla Cloud account needed to create managed alternator cluster.
# Can be empty string when testing only dynamoDB.
variable "scylla_cloud_token" {
	sensitive = true
}

# Instance type for alternator cluster, i4i family is recommended for real benchmarks.
variable "scylla_cloud_node_type" {
	default = "t3.micro"
}

# This is version needs to be updated to the desired version (typicially latest available).
variable "scylla_cloud_version" {
	default = "2022.1.3"
	# default = "5.1.1"
}

# See https://docs.scylladb.com/stable/alternator/alternator.html#write-isolation-policies
variable "alternator_write_isolation" {
	default = "only_rmw_uses_lwt"
}
