
output "db_connection_string" {
  value = "${aws_db_instance.db.address}:${aws_db_instance.db.port}/${aws_db_instance.db.db_name}"
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.website.domain_name
}

output "ec2_instance_public_ip_address" {
  value = aws_eip.server.public_ip
}

output "s3_bucket_name" {
  value = aws_s3_bucket.cat.bucket
}
