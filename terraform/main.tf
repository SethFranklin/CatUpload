
terraform {
  required_version = ">= 1.6.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.98.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.7.2"
    }
  }
  backend "s3" {
  }
}

locals {
  REGION = "us-east-1"

  ADDRESS_SPACE = "10.0.0.0/24"

  subnet_cidrs = cidrsubnets(local.ADDRESS_SPACE, 2, 2, 2)
}

provider "aws" {
  region = local.REGION
}

provider "random" {
}

resource "aws_vpc" "cat" {
  cidr_block = local.ADDRESS_SPACE

  tags = {
    Name = "Cat VPC"
  }
}

resource "aws_subnet" "dmz" {
  vpc_id            = aws_vpc.cat.id
  cidr_block        = local.subnet_cidrs[0]
  availability_zone = "${local.REGION}a"

  tags = {
    Name = "DMZ Subnet"
  }
}

resource "aws_security_group" "dmz" {
  name        = "dmz_sg"
  description = "DMZ Security Group"
  vpc_id      = aws_vpc.cat.id

  tags = {
    Name = "DMZ Security Group"
  }
}

resource "aws_vpc_security_group_ingress_rule" "dmz_allow_internet_ssh" {
  security_group_id = aws_security_group.dmz.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "tcp"
  from_port   = 22
  to_port     = 22
}

resource "aws_vpc_security_group_ingress_rule" "dmz_allow_internet_http" {
  security_group_id = aws_security_group.dmz.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "tcp"
  from_port   = 80
  to_port     = 80
}

resource "aws_vpc_security_group_egress_rule" "dmz_allow_all_outbound" {
  security_group_id = aws_security_group.dmz.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = -1
}

resource "aws_subnet" "db_a" {
  vpc_id            = aws_vpc.cat.id
  cidr_block        = local.subnet_cidrs[1]
  availability_zone = "${local.REGION}a"

  tags = {
    Name = "DB Subnet AZ A"
  }
}

resource "aws_subnet" "db_b" {
  vpc_id            = aws_vpc.cat.id
  cidr_block        = local.subnet_cidrs[2]
  availability_zone = "${local.REGION}b"

  tags = {
    Name = "DB Subnet AZ B"
  }
}

resource "aws_route_table" "db" {
  vpc_id = aws_vpc.cat.id

  tags = {
    Name = "DB Route Table"
  }
}

resource "aws_route_table_association" "db_a" {
  subnet_id      = aws_subnet.db_a.id
  route_table_id = aws_route_table.db.id
}

resource "aws_route_table_association" "db_b" {
  subnet_id      = aws_subnet.db_b.id
  route_table_id = aws_route_table.db.id
}

resource "aws_security_group" "db" {
  name        = "db_sg"
  description = "DB Security Group"
  vpc_id      = aws_vpc.cat.id

  tags = {
    Name = "DB Security Group"
  }
}

resource "aws_vpc_security_group_ingress_rule" "db_allow_dmz" {
  security_group_id = aws_security_group.db.id

  referenced_security_group_id = aws_security_group.dmz.id
  ip_protocol                  = "tcp"
  from_port                    = 1521
  to_port                      = 1521
}

resource "aws_internet_gateway" "cat" {
  vpc_id = aws_vpc.cat.id

  tags = {
    Name = "Cat Internet Gateway"
  }
}

resource "aws_route" "internet_bound_route" {
  route_table_id         = aws_vpc.cat.default_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.cat.id
}

resource "aws_network_interface" "server" {
  subnet_id       = aws_subnet.dmz.id
  private_ips     = [cidrhost(aws_subnet.dmz.cidr_block, 4)]
  security_groups = [aws_security_group.dmz.id]
}

resource "aws_eip" "server" {
  domain   = "vpc"
  instance = aws_instance.server.id
}

data "aws_ami" "server" {
  most_recent = true

  filter {
    name   = "name"
    values = ["RHEL-10.*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["309956199498"] # Red Hat
}

resource "aws_key_pair" "server" {
  key_name   = "server_key"
  public_key = file(var.ssh_public_key_file)
}

resource "aws_iam_role" "server" {
  name = "server_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name = "Cat Server Role"
  }
}

resource "aws_iam_instance_profile" "server" {
  name = "server_profile"
  role = aws_iam_role.server.name
}

resource "aws_instance" "server" {
  ami           = data.aws_ami.server.id
  instance_type = "t2.micro"

  key_name = aws_key_pair.server.key_name

  network_interface {
    network_interface_id = aws_network_interface.server.id
    device_index         = 0
  }

  iam_instance_profile = aws_iam_instance_profile.server.name

  tags = {
    Name = "Cat Server"
  }
}

resource "aws_db_subnet_group" "db" {
  name       = "db_subnet_group"
  subnet_ids = [aws_subnet.db_a.id, aws_subnet.db_b.id]

  tags = {
    Name = "DB Subnet Group"
  }
}

data "aws_rds_engine_version" "db" {
  engine = "oracle-se2"
  latest = true
}

resource "aws_db_instance" "db" {
  allocated_storage   = 20
  db_name             = "catdb"
  engine              = data.aws_rds_engine_version.db.engine
  engine_version      = data.aws_rds_engine_version.db.version_actual
  license_model       = "license-included"
  instance_class      = "db.m5.large"
  username            = "admin_user"
  password            = "admin_pass"
  skip_final_snapshot = true

  db_subnet_group_name   = aws_db_subnet_group.db.name
  vpc_security_group_ids = [aws_security_group.db.id]
}

resource "random_pet" "bucket_name_prefix" {
  length    = 2
  separator = "."
}

resource "random_string" "bucket_name_affix" {
  length  = 62 - length(random_pet.bucket_name_prefix.id)
  special = false
  upper   = false
}

resource "aws_s3_bucket" "cat" {
  bucket = "${random_pet.bucket_name_prefix.id}.${random_string.bucket_name_affix.result}"

  tags = {
    Name = "Cat S3 Bucket"
  }
}

resource "aws_s3_bucket_website_configuration" "cat" {
  bucket = aws_s3_bucket.cat.bucket

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "404.html"
  }
}

resource "aws_s3_bucket_public_access_block" "cat" {
  bucket = aws_s3_bucket.cat.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_cloudfront_distribution" "website" {
  origin {
    domain_name = aws_s3_bucket_website_configuration.cat.website_endpoint
    origin_id   = random_pet.bucket_name_prefix.id
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["SSLv3", "TLSv1", "TLSv1.1", "TLSv1.2"]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Cat CDN"
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = random_pet.bucket_name_prefix.id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }

  price_class = "PriceClass_100"

  custom_error_response {
    error_code         = 404
    response_code      = 404
    response_page_path = "/404.html"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "Cat CDN"
  }
}

data "aws_iam_policy_document" "s3" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.cat.arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }

  statement {
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.cat.arn}/cats/*"]
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.server.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "s3" {
  bucket = aws_s3_bucket.cat.id
  policy = data.aws_iam_policy_document.s3.json
}