output "loader_public_ips" {
  value = aws_instance.loader.*.public_ip
}

output "cluster_private_ips" {
  value =  local.scylla_testing ? scylladbcloud_cluster.scylla[0].node_private_ips : null
}

output "cluster_dns_names" {
  value =  local.scylla_testing ? scylladbcloud_cluster.scylla[0].node_dns_names : null
}
