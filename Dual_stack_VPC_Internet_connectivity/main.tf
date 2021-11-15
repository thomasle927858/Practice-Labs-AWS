provider "aws" {
  region = "us-west-2"
  # authentication
  # shared_credentials_file = "/enter/path/to/file"
  # profile = "whatever_custom_profile"
  # AWS profile name as set in the shared credentials file
}

locals {
  public_subnets = {
    "public_subnet_1" = {"az" = "us-west-2a", "cidr_block" = "${cidrsubnet(aws_vpc.example-01.cidr_block, 8, 1)}", "ipv6_cidr_block" = "${cidrsubnet(aws_vpc.example-01.ipv6_cidr_block, 8, 1)}"}, 
    "public_subnet_2" = {"az" = "us-west-2b", "cidr_block" = "${cidrsubnet(aws_vpc.example-01.cidr_block, 8, 4)}", "ipv6_cidr_block" = "${cidrsubnet(aws_vpc.example-01.ipv6_cidr_block, 8, 4)}"}, 
    "public_subnet_3" = {"az" = "us-west-2c", "cidr_block" = "${cidrsubnet(aws_vpc.example-01.cidr_block, 8, 7)}", "ipv6_cidr_block" = "${cidrsubnet(aws_vpc.example-01.ipv6_cidr_block, 8, 7)}"}
  }
  private_subnets = {
    "private_subnet_1" = {"az" = "us-west-2a", "cidr_block" = "${cidrsubnet(aws_vpc.example-01.cidr_block, 8, 2)}", "ipv6_cidr_block" = "${cidrsubnet(aws_vpc.example-01.ipv6_cidr_block, 8, 2)}"}, 
    "private_subnet_2" = {"az" = "us-west-2b", "cidr_block" = "${cidrsubnet(aws_vpc.example-01.cidr_block, 8, 5)}", "ipv6_cidr_block" = "${cidrsubnet(aws_vpc.example-01.ipv6_cidr_block, 8, 5)}"}, 
    "private_subnet_3" = {"az" = "us-west-2c", "cidr_block" = "${cidrsubnet(aws_vpc.example-01.cidr_block, 8, 8)}", "ipv6_cidr_block" = "${cidrsubnet(aws_vpc.example-01.ipv6_cidr_block, 8, 8)}"}
  }
  private_public_map = zipmap(keys(local.private_subnets), keys(local.public_subnets))
}

# Virtual Private Cloud (VPC)
resource "aws_vpc" "example-01" {
  assign_generated_ipv6_cidr_block = true # requests an IPv6 CIDR block provided by Amazon
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true # required for private DNS for interface endpoints
  enable_dns_support = true # required for private DNS for interface endpoints
  instance_tenancy = "default" # default (instances shared on host)
  tags = {
    "Name" = "example-01"
    "Project ID" = "69a201d1-63c6-4184-b000-8d54931a03e6"
  }
}

# Create Public Subnets
resource "aws_subnet" "public" {
  for_each = local.public_subnets
  vpc_id = aws_vpc.example-01.id
  availability_zone = each.value.az
  cidr_block = each.value.cidr_block # the IPv4 CIDR block for the subnet
  ipv6_cidr_block = each.value.ipv6_cidr_block # the IPv6 CIDR block for the subnet
  map_public_ip_on_launch = true # network interfaces created in this subnet should be assigned a public IP address
  assign_ipv6_address_on_creation = true # network interfaces created in this subnet should be assigned an IPv6 address

  tags = {
    "Name" = "public-${each.value.az}"
    "Project ID" = "08cced01-e5c5-481c-98b8-a8cd5acd2fcf"
  }
}

# Create Private Subnets
resource "aws_subnet" "private" {
  for_each = local.private_subnets
  vpc_id = aws_vpc.example-01.id
  availability_zone = each.value.az
  cidr_block = each.value.cidr_block # the IPv4 CIDR block for the subnet
  ipv6_cidr_block = each.value.ipv6_cidr_block # the IPv6 CIDR block for the subnet
  map_public_ip_on_launch = false # default, network interfaces created in this subnet should NOT be assigned a public IP address
  assign_ipv6_address_on_creation = true # network interfaces created in this subnet should be assigned an IPv6 address

  tags = {
    "Name" = "private-${each.value.az}"
    "Project ID" = "69a201d1-63c6-4184-b000-8d54931a03e6"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.example-01.id
  
  tags = {
    "Name" = "igw"
    "Project ID" = "69a201d1-63c6-4184-b000-8d54931a03e6"
  }
}

# Create an Egress-Only Internet Gateway (enable outbound communication over IPv6 from instances in your VPC to the Internet)
resource "aws_egress_only_internet_gateway" "eigw" {
  vpc_id = aws_vpc.example-01.id
  
  tags = {
    "Name" = "eigw"
    "Project ID" = "69a201d1-63c6-4184-b000-8d54931a03e6"
  }
}

# Create an Elastic IP for each NAT Gateway in each public subnet
resource "aws_eip" "NATgw" {
  for_each = local.public_subnets

  vpc = true # the Elastic IP is in a VPC

  tags = {
    "Name" = "EIP-NATgw-${each.value.az}"
    "Project ID" = "69a201d1-63c6-4184-b000-8d54931a03e6"
  }
}

# Create a NAT Gateway for each public subnet
resource "aws_nat_gateway" "NATgw" {
  for_each = local.public_subnets
  allocation_id = aws_eip.NATgw[each.key].id # the Allocation ID of the elastic IP address
  subnet_id = aws_subnet.public[each.key].id # the NAT gateway will be placed in the public subnet

  tags = {
    "Name" = "NATgw-${each.value.az}"
    "Project ID" = "69a201d1-63c6-4184-b000-8d54931a03e6"
  }
}

# Create a route table for each public subnet
resource "aws_route_table" "public" {
  for_each = local.public_subnets
  vpc_id = aws_vpc.example-01.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  
  route {
    ipv6_cidr_block = "::/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    "Name" = "public-rt-${each.value.az}"
    "Project ID" = "69a201d1-63c6-4184-b000-8d54931a03e6"
  }
}

# Create a route table association to associate each "public" route table to each public subnet
resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public
  route_table_id = aws_route_table.public[each.key].id
  subnet_id = each.value.id
}

# Create a route table for each private subnet
resource "aws_route_table" "private" {
  for_each = local.private_subnets
  vpc_id = aws_vpc.example-01.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.NATgw[local.private_public_map[each.key]].id
  }

  route {
    ipv6_cidr_block = "::/0"
    egress_only_gateway_id = aws_egress_only_internet_gateway.eigw.id
  }

  tags = {
    "Name" = "private-rt-${each.value.az}"
    "Project ID" = "69a201d1-63c6-4184-b000-8d54931a03e6"
  }
}

# Create a route table association to associate each "private" route table to each private subnet
resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private
  route_table_id = aws_route_table.private[each.key].id
  subnet_id = each.value.id
}

# Launch Template
resource "aws_launch_template" "Amazon_Linux_2" {
  block_device_mappings {
    device_name = "/dev/xvda" # root device name
    ebs {
      delete_on_termination = true # delete EBS volume when EC2 instance terminates
      encrypted = false # default
      volume_size = 8 # size in GiB
      volume_type = "gp2"
    }
  }
  credit_specification {
    cpu_credits = "standard" # for burstable performance instances, only allows an instance to burst above baseline by spending CPU credits in its credit balance
  }
  description = "Sample Amazon Linux launch template"
  disable_api_termination = false # disables EC2 Instance Termination Protection
  image_id = "ami-00be885d550dcee43"
  instance_initiated_shutdown_behavior = "terminate"
  
  instance_type = "t3.micro"
  monitoring {
    enabled = false # detailed monitoring disabled for the launched EC2 instance
  }
  name = "Amazon_Linux_2_launch_template_Sep_2021"
  network_interfaces {
    description = "example network interface"
    device_index = 0
  }
  tag_specifications {
    resource_type = "instance"
    tags = {
      "Project ID" = "69a201d1-63c6-4184-b000-8d54931a03e6"
    }
  }
}

# Launch a EC2 instance in each public subnet
resource "aws_instance" "public" {
  for_each = local.public_subnets
  subnet_id = aws_subnet.public[each.key].id
  instance_type = "t3.micro"
  launch_template {
    id = aws_launch_template.Amazon_Linux_2.id
  }
  tags = {
    "Name" = "test-public-${each.value.az}"
    "Project ID" = "69a201d1-63c6-4184-b000-8d54931a03e6"
  }
}

# Launch a EC2 instance in each private subnet
resource "aws_instance" "private" {
  for_each = local.private_subnets
  subnet_id = aws_subnet.private[each.key].id
  instance_type = "t3.micro"
  launch_template {
    id = aws_launch_template.Amazon_Linux_2.id
  }
  tags = {
    "Name" = "test-private-${each.value.az}"
    "Project ID" = "69a201d1-63c6-4184-b000-8d54931a03e6"
  }
}