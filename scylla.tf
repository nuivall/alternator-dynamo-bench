provider "scylladbcloud" {
  endpoint = "https://api.cloud.scylladb.com"
  token = var.scylla_cloud_token
}

data "aws_caller_identity" "current" {}

locals {
  scylla_testing = !var.dynamo_testing
  account_id = data.aws_caller_identity.current.account_id
}

resource "scylladbcloud_cluster" "scylla" {
  count  = local.scylla_testing ? 1 : 0
	name       = "Benchmarking"
	region     = var.aws_region
  scylla_version = var.scylla_cloud_version
  node_type  = var.scylla_cloud_node_type
  user_api_interface = "ALTERNATOR"
  alternator_write_isolation = var.alternator_write_isolation

	node_count = 3
	cidr_block = "172.31.0.0/16"
  
	enable_vpc_peering = true
	enable_dns         = true
}

resource "scylladbcloud_vpc_peering" "scylla_pc" {
  count  = local.scylla_testing ? 1 : 0

	cluster_id = scylladbcloud_cluster.scylla[count.index].id
	datacenter = scylladbcloud_cluster.scylla[count.index].datacenter

	peer_vpc_id     = aws_vpc.loader_vpc.id
	peer_cidr_block = aws_vpc.loader_vpc.cidr_block
	peer_region     = var.aws_region
	peer_account_id = local.account_id

	allow_cql = true
}

# This is accepting peering connection on the loaders VPC side.
resource "aws_vpc_peering_connection_accepter" "loader_accepter" {
  count  = local.scylla_testing ? 1 : 0

  #provider                  = aws.peer
  vpc_peering_connection_id = scylladbcloud_vpc_peering.scylla_pc[count.index].connection_id
  auto_accept               = true
}

# This is needed so that traffic from loaders can flow to the peered cluster.
resource "aws_route" "cluster_rt" {
  count  = local.scylla_testing ? 1 : 0

  route_table_id            = aws_route_table.main_rt.id
  destination_cidr_block    = scylladbcloud_cluster.scylla[count.index].cidr_block
  vpc_peering_connection_id = scylladbcloud_vpc_peering.scylla_pc[count.index].connection_id
}
