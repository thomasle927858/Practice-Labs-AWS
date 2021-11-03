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
  enable_dns_hostnames = true # required for private DNS for interface endpoints
  enable_dns_support = true # required for private DNS for interface endpoints
  instance_tenancy = "default" # default (instances shared on host)
  tags = {
    "Name" = "example-01"
    "Project ID" = "e2f8a927-d0ee-40e1-86fd-47aa677e2481"
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
    "Project ID" = "e2f8a927-d0ee-40e1-86fd-47aa677e2481"
  }
}

# Create a VPC Route Table for the "private" subnet
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.example-01.id
  route = [] # remove all managed routes

  tags = {
    "Name" = "private"
    "Project ID" = "e2f8a927-d0ee-40e1-86fd-47aa677e2481"
  }
}

# Associate the "private" route table with the "private" subnet
resource "aws_route_table_association" "private" {
  route_table_id = aws_route_table.private.id
  subnet_id = aws_subnet.private.id
}

# AWS Systems Manager VPC endpoints documentation:
# https://docs.aws.amazon.com/systems-manager/latest/userguide/setup-create-vpc.html
# create a VPC gateway endpoint for S3
resource "aws_vpc_endpoint" "s3" {
  vpc_id = aws_vpc.example-01.id

  vpc_endpoint_type = "Gateway"
  service_name = "com.amazonaws.us-west-1.s3"
  route_table_ids = [aws_route_table.private.id]
  policy = file("${path.module}/s3-vpc-endpoint-policy.json")

  tags = {
    "Name" = "S3 endpoint for us-west-1"
    "Project ID" = "e2f8a927-d0ee-40e1-86fd-47aa677e2481"
  }
}

# Create a S3 bucket
resource "aws_s3_bucket" "example" {
  bucket = "9d1ee2d2-ac45-409d-90f3-d25e226d0a9e" # the name of the bucket
  # S3 bucket policy
  policy = file("${path.module}/bucket_policy_9d1ee2d2-ac45-409d-90f3-d25e226d0a9e.json")

  versioning {
    enabled = true # source bucket must have versioning enabled for replication
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
    "Project ID" = "e2f8a927-d0ee-40e1-86fd-47aa677e2481"
  }
}

# block public access to the bucket
resource "aws_s3_bucket_public_access_block" "example" {
  bucket = aws_s3_bucket.example.id

  block_public_acls = true # Block public access to buckets and objects granted through new access control lists (ACLs)
  ignore_public_acls = true # Block public access to buckets and objects granted through any access control lists (ACLs)
  block_public_policy = true # Block public access to buckets and objects granted through new public bucket or access point policies
  restrict_public_buckets = true # Block public and cross-account access to buckets and objects through any public bucket or access point policies
}

resource "aws_security_group" "EC2_example" {
  vpc_id = aws_vpc.example-01.id
  
  ingress = [
    {
      # processed in attribute-as-blocks mode
      description = "allow port 443 from security group"
      from_port = 443
      to_port = 443
      protocol = "tcp"
      cidr_blocks = null
      ipv6_cidr_blocks = null
      prefix_list_ids = null
      security_groups = null
      self = true
    }
  ]
  egress = [
    {
      # processed in attribute-as-blocks mode
      description = "allow egress traffic to any destination with any protocol"
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      prefix_list_ids = null
      security_groups = null
      self = null
    }
  ]
  tags = {
    "Name" = "EC2_example"
    "Project ID" = "e2f8a927-d0ee-40e1-86fd-47aa677e2481"
  }
}

# launch template
resource "aws_launch_template" "Amazon_Linux_2" {
  block_device_mappings {
    device_name = "/dev/xvda" # root device name
    ebs {
      delete_on_termination = true # delete EBS volume when EC2 instance terminates
      encrypted = false # default
      volume_size = 10 # size in GiB
      volume_type = "gp2"
    }
  }
  credit_specification {
    cpu_credits = "standard" # for burstable performance instances, only allows an instance to burst above baseline by spending CPU credits in its credit balance
  }
  description = "Sample Amazon Linux launch template"
  disable_api_termination = false # disables EC2 Instance Termination Protection
  image_id = "ami-011996ff98de391d1"
  instance_initiated_shutdown_behavior = "terminate"
  
  instance_type = "t3.micro"
  monitoring {
    enabled = false # detailed monitoring disabled for the launched EC2 instance
  }
  name = "Amazon_Linux_2_launch_template_Sep_2021"
  network_interfaces {
    description = "example network interface"
    device_index = 0
    security_groups = [aws_security_group.EC2_example.id]  # collection type set of str
    subnet_id = aws_subnet.private.id # type str
  }
  tag_specifications {
    resource_type = "instance"
    tags = {
      "Project ID" = "e2f8a927-d0ee-40e1-86fd-47aa677e2481"
    }
  }
}

data "aws_iam_instance_profile" "AmazonSSMManagedInstanceCore" {
  name = "AmazonSSMManagedInstanceCore"
}

# create an instance in the "private" subnet of the example-01 VPC
resource "aws_instance" "test1" {
  iam_instance_profile = data.aws_iam_instance_profile.AmazonSSMManagedInstanceCore.role_name
  instance_type = "t3.micro"
  launch_template {
    id = aws_launch_template.Amazon_Linux_2.id
  }
  tags = {
    "Name" = "test1"
    "Project ID" = "e2f8a927-d0ee-40e1-86fd-47aa677e2481"
  }
}

# create a security group for the interface endpoints
resource "aws_security_group" "SSM_interface_endpoints" {
  vpc_id = aws_vpc.example-01.id
  
  ingress = [
    {
      # processed in attribute-as-blocks mode
      description = "allow all ingress traffic from security group named EC2_example"
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = null
      ipv6_cidr_blocks = null
      prefix_list_ids = null
      security_groups = [aws_security_group.EC2_example.id]
      self = null
    }
  ]
  egress = [
    {
      # processed in attribute-as-blocks mode
      description = "allow egress traffic to any destination with any protocol"
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      prefix_list_ids = null
      security_groups = null
      self = null
    }
  ]
  tags = {
    "Name" = "SSM_interface_endpoints"
    "Project ID" = "e2f8a927-d0ee-40e1-86fd-47aa677e2481"
  }
}

# create the interface endpoint for the services
resource "aws_vpc_endpoint" "SSM_interface_endpoints" {
  vpc_id = aws_vpc.example-01.id

  for_each = toset(["com.amazonaws.us-west-1.ssm", "com.amazonaws.us-west-1.ssmmessages", "com.amazonaws.us-west-1.ec2", "com.amazonaws.us-west-1.ec2messages", "com.amazonaws.us-west-1.kms"]) # set of str
  service_name = each.key
  
  vpc_endpoint_type = "Interface"

  subnet_ids = [aws_subnet.private.id]
  security_group_ids = [aws_security_group.SSM_interface_endpoints.id]

  private_dns_enabled = true

  tags = {
    "Name" = each.key
    "Project ID" = "e2f8a927-d0ee-40e1-86fd-47aa677e2481"
  }
}