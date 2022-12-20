output "loader_public_ips" {
  value = aws_instance.loader.*.public_ip
}