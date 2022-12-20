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
  default = "t2.micro"
}

variable "loader_instances_count" {
	default = 3
}