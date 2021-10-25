provider "aws" {
  region = "us-west-1"
  # authentication
  # shared_credentials_file = "/enter/path/to/file"
  # profile = "whatever_custom_profile"
  # AWS profile name as set in the shared credentials file
}

# Virtual Private Cloud (VPC)
resource "aws_vpc" "example-01" {
  assign_generated_ipv6_cidr_block = false # does not request an IPv6 CIDR block provided by Amazon; default
  cidr_block = "172.16.0.0/16"
  enable_dns_hostnames = false # default
  enable_dns_support = true # default
  instance_tenancy = "default" # default (instances shared on host)
  tags = {
    "Name" = "example-01"
    "Project ID" = "b8658d6b-583f-46fd-8eca-d1a659425e4d"
  }
}

# Create Private Subnet
resource "aws_subnet" "private" {
  vpc_id = aws_vpc.example-01.id
  availability_zone = "us-west-1c"
  cidr_block = "172.16.3.0/24" # the IPv4 CIDR block for the subnet
  map_public_ip_on_launch = false # default, network interfaces created in this subnet should NOT be assigned a public IP address
  assign_ipv6_address_on_creation = false # default, network interfaces created in this subnet should not be assigned an IPv6 address

  tags = {
    "Name" = "private"
    "Project ID" = "b8658d6b-583f-46fd-8eca-d1a659425e4d"
  }
}

# Create a VPC Route Table for the "private" subnet
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.example-01.id
  route = [] # remove all managed routes

  tags = {
    "Name" = "private"
    "Project ID" = "b8658d6b-583f-46fd-8eca-d1a659425e4d"
  }
}

# Associate the "private" route table with the "private" subnet
resource "aws_route_table_association" "private" {
  route_table_id = aws_route_table.private.id
  subnet_id = aws_subnet.private.id
}

# create a VPC gateway endpoint for S3
resource "aws_vpc_endpoint" "s3" {
  vpc_id = aws_vpc.example-01.id

  vpc_endpoint_type = "Gateway"
  service_name = "com.amazonaws.us-west-1.s3"
  route_table_ids = [aws_route_table.private.id]
  policy = file("${path.module}/s3-vpc-endpoint-policy.json")

  tags = {
    "Name" = "S3 endpoint for us-west-1"
    "Project ID" = "b8658d6b-583f-46fd-8eca-d1a659425e4d"
  }
}

# Create a S3 bucket
resource "aws_s3_bucket" "example" {
  bucket = "9d1ee2d2-ac45-409d-90f3-d25e226d0a9e" # the name of the bucket
  # S3 bucket policy
  policy = file("${path.module}/bucket_policy_9d1ee2d2-ac45-409d-90f3-d25e226d0a9e.json")

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256" # SSE-S3 (server-side encryption with Amazon S3)
      }
    }
  }

  tags = {
    "Name" = "9d1ee2d2-ac45-409d-90f3-d25e226d0a9e"
    "Project ID" = "b8658d6b-583f-46fd-8eca-d1a659425e4d"
  }
}