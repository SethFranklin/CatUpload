
output "rds_host_and_port" {
  value = "${aws_db_instance.db.address}:${aws_db_instance.db.port}"
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.website.domain_name
}

output "ec2_instance_public_ip_address" {
  value = aws_eip.server.address
}