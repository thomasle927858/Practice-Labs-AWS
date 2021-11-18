provider "aws" {
  region = "us-west-2"
  # authentication
  # shared_credentials_file = "/enter/path/to/file"
  # profile = "whatever_custom_profile"
  # AWS profile name as set in the shared credentials file
}

locals {
  # AWS Transit Gateway subnets for Spoke-1 VPC
  Spoke-1_TGW_subnets = {
    "TGW_subnet_1" = {"az" = "us-west-2a", "cidr_block" = "${cidrsubnet(aws_vpc.Spoke-1.cidr_block, 12, 0)}", "vpc" = "Spoke-1"}, 
    "TGW_subnet_2" = {"az" = "us-west-2b", "cidr_block" = "${cidrsubnet(aws_vpc.Spoke-1.cidr_block, 12, 1)}", "vpc" = "Spoke-1"}
  }
  # private subnets contianing workloads for Spoke-1 VPC
  Spoke-1_private_subnets = {
    "private_subnet_1" = {"az" = "us-west-2a", "cidr_block" = "${cidrsubnet(aws_vpc.Spoke-1.cidr_block, 8, 1)}", "vpc" = "Spoke-1"}, 
    "private_subnet_2" = {"az" = "us-west-2b", "cidr_block" = "${cidrsubnet(aws_vpc.Spoke-1.cidr_block, 8, 2)}", "vpc" = "Spoke-1"} 
  }
  # AWS Transit Gateway subnets for Spoke-2 VPC
  Spoke-2_TGW_subnets = {
    "TGW_subnet_1" = {"az" = "us-west-2a", "cidr_block" = "${cidrsubnet(aws_vpc.Spoke-2.cidr_block, 12, 0)}", "vpc" = "Spoke-2"}, 
    "TGW_subnet_2" = {"az" = "us-west-2b", "cidr_block" = "${cidrsubnet(aws_vpc.Spoke-2.cidr_block, 12, 1)}", "vpc" = "Spoke-2"}
  }
  # private subnets contianing workloads for Spoke-2 VPC
  Spoke-2_private_subnets = {
    "private_subnet_1" = {"az" = "us-west-2a", "cidr_block" = "${cidrsubnet(aws_vpc.Spoke-2.cidr_block, 8, 1)}", "vpc" = "Spoke-2"}, 
    "private_subnet_2" = {"az" = "us-west-2b", "cidr_block" = "${cidrsubnet(aws_vpc.Spoke-2.cidr_block, 8, 2)}", "vpc" = "Spoke-2"} 
  }
  # AWS Transit Gateway subnets for Internet-Egress VPC
  Internet-Egress_TGW_subnets = {
    "TGW_subnet_1" = {"az" = "us-west-2a", "cidr_block" = "${cidrsubnet(aws_vpc.Internet-Egress.cidr_block, 12, 0)}", "vpc" = "Internet-Egress"}, 
    "TGW_subnet_2" = {"az" = "us-west-2b", "cidr_block" = "${cidrsubnet(aws_vpc.Internet-Egress.cidr_block, 12, 1)}", "vpc" = "Internet-Egress"}
  }
  # public subnets for NAT Gateways in Internet-Egress VPC
  Internet-Egress_NATGW_subnets = {
    "NATGW_subnet_1" = {"az" = "us-west-2a", "cidr_block" = "${cidrsubnet(aws_vpc.Internet-Egress.cidr_block, 8, 1)}", "vpc" = "Internet-Egress"}, 
    "NATGW_subnet_2" = {"az" = "us-west-2b", "cidr_block" = "${cidrsubnet(aws_vpc.Internet-Egress.cidr_block, 8, 2)}", "vpc" = "Internet-Egress"} 
  }
  # map
  Internet-Egress_TGW_NATGW_map = zipmap(keys(local.Internet-Egress_TGW_subnets), keys(local.Internet-Egress_NATGW_subnets))
}

# Create an AWS Transit Gateway
resource "aws_ec2_transit_gateway" "TGW1" {
  auto_accept_shared_attachments = "disable" # resource attachment requests should not be automatically accepted
  default_route_table_association = "disable" # resource attachments are not automatically associated with the default association route table
  default_route_table_propagation = "disable" # resource attachments do not automatically propagate routes to the default propagation route table
  dns_support = "enable"

  tags = {
    "Name" = "TGW1"
    "Project ID" = "b21626ab-0365-4034-82b6-2a58d36fbc94"
  }  
}

# Spoke Route Table (will be associated with AWS Transit Gateway attachments in Spoke-1 and Spoke-2 VPCs)
resource "aws_ec2_transit_gateway_route_table" "Spoke" {
  transit_gateway_id = aws_ec2_transit_gateway.TGW1.id

  tags = {
    "Name" = "Spoke-route-table"
    "Project ID" = "b21626ab-0365-4034-82b6-2a58d36fbc94"
  }
}

# Route destination 0.0.0.0/0 to Transit Gateway VPC attachment of Internet Egress VPC
resource "aws_ec2_transit_gateway_route" "to_internet" {
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.Internet-Egress.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.Spoke.id
}

# Route destination 10.0.0.0/15 blackholed (no communication between Spoke VPCs)
resource "aws_ec2_transit_gateway_route" "block_spoke_VPCs_communication" {
  destination_cidr_block = "10.0.0.0/15" # Spoke-1 and Spoke-2 CIDR range
  blackhole = true
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.Spoke.id
}

# Egress Route Table (will be associated with AWS Transit Gateway attachments in the Internet-Egress VPC)
resource "aws_ec2_transit_gateway_route_table" "Egress" {
  transit_gateway_id = aws_ec2_transit_gateway.TGW1.id

  tags = {
    "Name" = "Egress-route-table"
    "Project ID" = "b21626ab-0365-4034-82b6-2a58d36fbc94"
  }
}

# Route destination 10.0.0.0/16 to Transit Gateway VPC attachment of Spoke-1 VPC
resource "aws_ec2_transit_gateway_route" "to_Spoke-1_VPC" {
  destination_cidr_block = aws_vpc.Spoke-1.cidr_block
  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.Spoke-1.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.Egress.id
}

# Route destination 10.1.0.0/16 to Transit Gateway VPC attachment of Spoke-2 VPC
resource "aws_ec2_transit_gateway_route" "to_Spoke-2_VPC" {
  destination_cidr_block = aws_vpc.Spoke-2.cidr_block
  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.Spoke-2.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.Egress.id
}

## EC2
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
      "Project ID" = "b21626ab-0365-4034-82b6-2a58d36fbc94"
    }
  }
}

########

# Virtual Private Cloud (VPC) Spoke-1
resource "aws_vpc" "Spoke-1" {
  assign_generated_ipv6_cidr_block = false # does not request an IPv6 CIDR block provided by Amazon
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true
  instance_tenancy = "default" # default (instances shared on host)
  tags = {
    "Name" = "Spoke-1"
    "Project ID" = "b21626ab-0365-4034-82b6-2a58d36fbc94"
  }
}

# Create Private Subnets (for AWS Transit Gateway) in Spoke-1 VPC
resource "aws_subnet" "Spoke-1_TGW" {
  for_each = local.Spoke-1_TGW_subnets
  vpc_id = aws_vpc.Spoke-1.id
  availability_zone = each.value.az
  cidr_block = each.value.cidr_block # the IPv4 CIDR block for the subnet
  map_public_ip_on_launch = false # default, network interfaces created in this subnet should NOT be assigned a public IP address

  tags = {
    "Name" = "VPC-${each.value.vpc}-TGW-${each.value.az}"
    "Project ID" = "b21626ab-0365-4034-82b6-2a58d36fbc94"
  }
}

# Network ACL for AWS Transit Gateway subnets in Spoke-1 VPC
resource "aws_network_acl" "Spoke-1-AWS-Transit-Gateway-NACL" {
  vpc_id = aws_vpc.Spoke-1.id
  subnet_ids = [for k, v in aws_subnet.Spoke-1_TGW : v.id]
  
  # inbound
  ingress {
    protocol = "-1"
    rule_no = 10
    action = "allow"
    cidr_block = "0.0.0.0/0"
    from_port = 0
    to_port = 0
  }

  # outbound
  egress {
    protocol = "-1"
    rule_no = 10
    action = "allow"
    cidr_block = "0.0.0.0/0"
    from_port = 0
    to_port = 0
  }

  tags = {
    Name = "Spoke-1-AWS-Transit-Gateway-NACL"
    "Project ID" = "b21626ab-0365-4034-82b6-2a58d36fbc94"
  }
}

# Create AWS Transit Gateway VPC attachment for a Transit Gateway subnet in each Availability Zone for the Spoke-1 VPC
resource "aws_ec2_transit_gateway_vpc_attachment" "Spoke-1" {
  subnet_ids = [for k, v in aws_subnet.Spoke-1_TGW: v.id]
  transit_gateway_id = aws_ec2_transit_gateway.TGW1.id
  vpc_id = aws_vpc.Spoke-1.id
  

  dns_support = "enable"
  ipv6_support = "disable"
  transit_gateway_default_route_table_association = false # the VPC Attachment should not be associated with the EC2 Transit Gateway association default route table
  transit_gateway_default_route_table_propagation = false # the VPC Attachment should not propagate routes with the EC2 Transit Gateway propagation default route table

  tags = {
    Name = "Spoke-1-VPC-TGW-attachment"
    "Project ID" = "b21626ab-0365-4034-82b6-2a58d36fbc94"
  }
}

# Create Private Subnets for workloads in Spoke-1 VPC
resource "aws_subnet" "Spoke-1_private_workload" {
  for_each = local.Spoke-1_private_subnets
  vpc_id = aws_vpc.Spoke-1.id
  availability_zone = each.value.az
  cidr_block = each.value.cidr_block # the IPv4 CIDR block for the subnet
  map_public_ip_on_launch = false # default, network interfaces created in this subnet should NOT be assigned a public IP address

  tags = {
    "Name" = "VPC-${each.value.vpc}-private-${each.value.az}"
    "Project ID" = "b21626ab-0365-4034-82b6-2a58d36fbc94"
  }
}

# Create a route table for each private subnet for workloads in Spoke-1 VPC
resource "aws_route_table" "Spoke-1_private_workload" {
  for_each = local.Spoke-1_private_subnets
  vpc_id = aws_vpc.Spoke-1.id

  route {
    cidr_block = "0.0.0.0/0"
    transit_gateway_id = aws_ec2_transit_gateway.TGW1.id
  }

  tags = {
    "Name" = "VPC-${each.value.vpc}-private-rt-${each.value.az}"
    "Project ID" = "b21626ab-0365-4034-82b6-2a58d36fbc94"
  }
}

# Create a route table association to associate each "private" route table to each private subnet for workloads in Spoke-1 VPC
resource "aws_route_table_association" "Spoke-1_private_workload" {
  for_each = aws_subnet.Spoke-1_private_workload
  route_table_id = aws_route_table.Spoke-1_private_workload[each.key].id
  subnet_id = each.value.id
}

# Associate Transit Gateway Route Table "Spoke" with AWS Transit Gateway attachments in Spoke-1 VPC
resource "aws_ec2_transit_gateway_route_table_association" "Spoke-1" {
  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.Spoke-1.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.Spoke.id
}

# Create a security group for the EC2 instances in the Spoke-1 VPC
resource "aws_security_group" "Spoke-1-protect-EC2" {
  name  = "Spoke-1-protect-EC2"
  description = "Security group to protect EC2 instances in the Spoke-1 VPC"
  vpc_id      = aws_vpc.Spoke-1.id
  
  # allow instances to communicate to any destination IPv4 address and destination TCP port 80 (HTTP) (and allow return traffic)
  egress {
    from_port = 80
    to_port  = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # allow instances to communicate to any destination IPv4 address and destination TCP port 443 (HTTPS) (and allow return traffic)
  egress {
    from_port = 443
    to_port  = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Spoke-1-protect-EC2"
  }
}

# Launch a EC2 instance in each private subnet in Spoke-1 VPC
resource "aws_instance" "Spoke-1_private" {
  for_each = local.Spoke-1_private_subnets
  security_groups = [aws_security_group.Spoke-1-protect-EC2.id]
  subnet_id = aws_subnet.Spoke-1_private_workload[each.key].id
  instance_type = "t3.micro"
  launch_template {
    id = aws_launch_template.Amazon_Linux_2.id
  }
  tags = {
    "Name" = "VPC-${each.value.vpc}-private-${each.value.az}"
    "Project ID" = "b21626ab-0365-4034-82b6-2a58d36fbc94"
  }
}

########

# Virtual Private Cloud (VPC) Spoke-2
resource "aws_vpc" "Spoke-2" {
  assign_generated_ipv6_cidr_block = false # does not request an IPv6 CIDR block provided by Amazon
  cidr_block = "10.1.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true
  instance_tenancy = "default" # default (instances shared on host)
  tags = {
    "Name" = "Spoke-2"
    "Project ID" = "b21626ab-0365-4034-82b6-2a58d36fbc94"
  }
}

# Create Private Subnets (for AWS Transit Gateway) in Spoke-2 VPC
resource "aws_subnet" "Spoke-2_TGW" {
  for_each = local.Spoke-2_TGW_subnets
  vpc_id = aws_vpc.Spoke-2.id
  availability_zone = each.value.az
  cidr_block = each.value.cidr_block # the IPv4 CIDR block for the subnet
  map_public_ip_on_launch = false # default, network interfaces created in this subnet should NOT be assigned a public IP address

  tags = {
    "Name" = "VPC-${each.value.vpc}-TGW-${each.value.az}"
    "Project ID" = "b21626ab-0365-4034-82b6-2a58d36fbc94"
  }
}

# Network ACL for AWS Transit Gateway subnets in Spoke-2 VPC
resource "aws_network_acl" "Spoke-2-AWS-Transit-Gateway-NACL" {
  vpc_id = aws_vpc.Spoke-2.id
  subnet_ids = [for k, v in aws_subnet.Spoke-2_TGW : v.id]
  
  # inbound
  ingress {
    protocol = "-1"
    rule_no = 10
    action = "allow"
    cidr_block = "0.0.0.0/0"
    from_port = 0
    to_port = 0
  }

  # outbound
  egress {
    protocol = "-1"
    rule_no = 10
    action = "allow"
    cidr_block = "0.0.0.0/0"
    from_port = 0
    to_port = 0
  }

  tags = {
    Name = "Spoke-2-AWS-Transit-Gateway-NACL"
    "Project ID" = "b21626ab-0365-4034-82b6-2a58d36fbc94"
  }
}

# Create AWS Transit Gateway VPC attachment for a Transit Gateway subnet in each Availability Zone for the Spoke-2 VPC
resource "aws_ec2_transit_gateway_vpc_attachment" "Spoke-2" {
  subnet_ids = [for k, v in aws_subnet.Spoke-2_TGW: v.id]
  transit_gateway_id = aws_ec2_transit_gateway.TGW1.id
  vpc_id = aws_vpc.Spoke-2.id
  

  dns_support = "enable"
  ipv6_support = "disable"
  transit_gateway_default_route_table_association = false # the VPC Attachment should not be associated with the EC2 Transit Gateway association default route table
  transit_gateway_default_route_table_propagation = false # the VPC Attachment should not propagate routes with the EC2 Transit Gateway propagation default route table

  tags = {
    Name = "Spoke-2-VPC-TGW-attachment"
    "Project ID" = "b21626ab-0365-4034-82b6-2a58d36fbc94"
  }
}

# Create Private Subnets for workloads in Spoke-2 VPC
resource "aws_subnet" "Spoke-2_private_workload" {
  for_each = local.Spoke-2_private_subnets
  vpc_id = aws_vpc.Spoke-2.id
  availability_zone = each.value.az
  cidr_block = each.value.cidr_block # the IPv4 CIDR block for the subnet
  map_public_ip_on_launch = false # default, network interfaces created in this subnet should NOT be assigned a public IP address

  tags = {
    "Name" = "VPC-${each.value.vpc}-private-${each.value.az}"
    "Project ID" = "b21626ab-0365-4034-82b6-2a58d36fbc94"
  }
}

# Create a route table for each private subnet for workloads in Spoke-2 VPC
resource "aws_route_table" "Spoke-2_private_workload" {
  for_each = local.Spoke-2_private_subnets
  vpc_id = aws_vpc.Spoke-2.id

  route {
    cidr_block = "0.0.0.0/0"
    transit_gateway_id = aws_ec2_transit_gateway.TGW1.id
  }

  tags = {
    "Name" = "VPC-${each.value.vpc}-private-rt-${each.value.az}"
    "Project ID" = "b21626ab-0365-4034-82b6-2a58d36fbc94"
  }
}

# Create a route table association to associate each "private" route table to each private subnet for workloads in Spoke-2 VPC
resource "aws_route_table_association" "Spoke-2_private_workload" {
  for_each = aws_subnet.Spoke-2_private_workload
  route_table_id = aws_route_table.Spoke-2_private_workload[each.key].id
  subnet_id = each.value.id
}

# Associate Transit Gateway Route Table "Spoke" with AWS Transit Gateway attachments in Spoke-2 VPC
resource "aws_ec2_transit_gateway_route_table_association" "Spoke-2" {
  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.Spoke-2.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.Spoke.id
}

# Create a security group for the EC2 instances in the Spoke-2 VPC
resource "aws_security_group" "Spoke-2-protect-EC2" {
  name  = "Spoke-2-protect-EC2"
  description = "Security group to protect EC2 instances in the Spoke-2 VPC"
  vpc_id      = aws_vpc.Spoke-2.id
  
  # allow instances to communicate to any destination IPv4 address and destination TCP port 80 (HTTP) (and allow return traffic)
  egress {
    from_port = 80
    to_port  = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # allow instances to communicate to any destination IPv4 address and destination TCP port 443 (HTTPS) (and allow return traffic)
  egress {
    from_port = 443
    to_port  = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Spoke-2-protect-EC2"
  }
}

# Launch a EC2 instance in each private subnet in Spoke-2 VPC
resource "aws_instance" "Spoke-2_private" {
  for_each = local.Spoke-2_private_subnets
  security_groups = [aws_security_group.Spoke-2-protect-EC2.id]
  subnet_id = aws_subnet.Spoke-2_private_workload[each.key].id
  instance_type = "t3.micro"
  launch_template {
    id = aws_launch_template.Amazon_Linux_2.id
  }
  tags = {
    "Name" = "VPC-${each.value.vpc}-private-${each.value.az}"
    "Project ID" = "b21626ab-0365-4034-82b6-2a58d36fbc94"
  }
}

########

# Virtual Private Cloud (VPC) Internet-Egress
resource "aws_vpc" "Internet-Egress" {
  assign_generated_ipv6_cidr_block = false # does not request an IPv6 CIDR block provided by Amazon
  cidr_block = "10.2.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true
  instance_tenancy = "default" # default (instances shared on host)
  tags = {
    "Name" = "Internet-Egress"
    "Project ID" = "b21626ab-0365-4034-82b6-2a58d36fbc94"
  }
}

# Create Private Subnets (for AWS Transit Gateway) in Internet-Egress VPC
resource "aws_subnet" "Internet-Egress_TGW" {
  for_each = local.Internet-Egress_TGW_subnets
  vpc_id = aws_vpc.Internet-Egress.id
  availability_zone = each.value.az
  cidr_block = each.value.cidr_block # the IPv4 CIDR block for the subnet
  map_public_ip_on_launch = false # default, network interfaces created in this subnet should NOT be assigned a public IP address

  tags = {
    "Name" = "VPC-${each.value.vpc}-TGW-${each.value.az}"
    "Project ID" = "b21626ab-0365-4034-82b6-2a58d36fbc94"
  }
}

# Create Public Subnets (for NAT Gateway) in Internet-Egress VPC
resource "aws_subnet" "Internet-Egress_NATGW" {
  for_each = local.Internet-Egress_NATGW_subnets
  vpc_id = aws_vpc.Internet-Egress.id
  availability_zone = each.value.az
  cidr_block = each.value.cidr_block # the IPv4 CIDR block for the subnet
  map_public_ip_on_launch = false # default, network interfaces created in this subnet should NOT be assigned a public IP address

  tags = {
    "Name" = "VPC-${each.value.vpc}-NATGW-${each.value.az}"
    "Project ID" = "b21626ab-0365-4034-82b6-2a58d36fbc94"
  }
}

/*
# Example Network ACL for public subnets in the Internet-Egress VPC that have a NAT Gateway
resource "aws_network_acl" "AWS-NAT-Gateway-NACL" {
  vpc_id = aws_vpc.Internet-Egress.id
  subnet_ids = [for k, v in aws_subnet.Internet-Egress_TGW : v.id]
  
  # inbound
  
  # Allow all inbound traffic from Spoke-1 VPC and Spoke-2 VPC
  ingress {
    protocol = "-1"
    rule_no = 10
    action = "allow"
    cidr_block = "10.0.0.0/15" # source 10.0.0.0/16 (Spoke-1 VPC IPv4 CIDR) and 10.1.0.0/16 (Spoke-2 VPC IPv4 CIDR)
    from_port = 0
    to_port = 0
  }

  # Allow inbound return traffic (using TCP at the transport layer) from hosts on the internet that are responding to requests originating in the subnet
  # A NAT gateway uses ports 1024-65535
  ingress {
    protocol = "tcp"
    rule_no = 20
    action = "allow"
    cidr_block = "0.0.0.0/0" # source IP CIDR block
    from_port = 1024
    to_port = 65535
  }

  # outbound
  
  # deny HTTP traffic on destination port 80 destined to Spoke-1 VPC and Spoke-2 VPC
  egress {
    protocol = "tcp"
    rule_no = 10
    action = "deny"
    cidr_block = "10.0.0.0/15" # destination 10.0.0.0/16 (Spoke-1 VPC IPv4 CIDR) and 10.1.0.0/16 (Spoke-2 VPC IPv4 CIDR)
    from_port = 80
    to_port = 80
  }

  # allow HTTP traffic to the Internet
  egress {
    protocol = "tcp"
    rule_no = 20
    action = "allow"
    cidr_block = "0.0.0.0/0"
    from_port = 80
    to_port = 80
  }

  # deny HTTPS traffic on destination port 443 destined to Spoke-1 VPC and Spoke-2 VPC
  egress {
    protocol = "tcp"
    rule_no = 30
    action = "deny"
    cidr_block = "10.0.0.0/15" # destination 10.0.0.0/16 (Spoke-1 VPC IPv4 CIDR) and 10.1.0.0/16 (Spoke-2 VPC IPv4 CIDR)
    from_port = 443
    to_port = 443
  }

  # allow HTTPS traffic to the Internet
  egress {
    protocol = "tcp"
    rule_no = 40
    action = "allow"
    cidr_block = "0.0.0.0/0"
    from_port = 443
    to_port = 443
  }

  # allow traffic destined to Spoke-1 VPC and Spoke-2 VPC
  egress {
    protocol = "-1"
    rule_no = 50
    action = "allow"
    cidr_block = "10.0.0.0/15" # destination 10.0.0.0/16 (Spoke-1 VPC IPv4 CIDR) and 10.1.0.0/16 (Spoke-2 VPC IPv4 CIDR)
    from_port = 0
    to_port = 0
  }

  tags = {
    Name = "AWS-NAT-Gateway-NACL"
    "Project ID" = "b21626ab-0365-4034-82b6-2a58d36fbc94"
  }
}
*/

# Network ACL for AWS Transit Gateway subnets in Internet-Egress VPC
resource "aws_network_acl" "Internet-Egress-AWS-Transit-Gateway-NACL" {
  vpc_id = aws_vpc.Internet-Egress.id
  subnet_ids = [for k, v in aws_subnet.Internet-Egress_TGW : v.id]
  
  # inbound
  ingress {
    protocol = "-1"
    rule_no = 10
    action = "allow"
    cidr_block = "0.0.0.0/0"
    from_port = 0
    to_port = 0
  }

  # outbound
  egress {
    protocol = "-1"
    rule_no = 10
    action = "allow"
    cidr_block = "0.0.0.0/0"
    from_port = 0
    to_port = 0
  }

  tags = {
    Name = "Internet-Egress-AWS-Transit-Gateway-NACL"
    "Project ID" = "b21626ab-0365-4034-82b6-2a58d36fbc94"
  }
}

# Create AWS Transit Gateway VPC attachment for a Transit Gateway subnet in each Availability Zone for the Internet-Egress VPC
resource "aws_ec2_transit_gateway_vpc_attachment" "Internet-Egress" {
  subnet_ids = [for k, v in aws_subnet.Internet-Egress_TGW: v.id]
  transit_gateway_id = aws_ec2_transit_gateway.TGW1.id
  vpc_id = aws_vpc.Internet-Egress.id
  

  dns_support = "enable"
  ipv6_support = "disable"
  transit_gateway_default_route_table_association = false # the VPC Attachment should not be associated with the EC2 Transit Gateway association default route table
  transit_gateway_default_route_table_propagation = false # the VPC Attachment should not propagate routes with the EC2 Transit Gateway propagation default route table

  tags = {
    Name = "Internet-Egress-VPC"
    "Project ID" = "b21626ab-0365-4034-82b6-2a58d36fbc94"
  }
}

# Create an Elastic IP for each NAT Gateway in each public subnet of the Internet-Egress VPC
resource "aws_eip" "NATgw" {
  for_each = local.Internet-Egress_NATGW_subnets

  vpc = true # the Elastic IP is in a VPC

  tags = {
    "Name" = "EIP-VPC-${each.value.vpc}-NATgw-${each.value.az}"
    "Project ID" = "b21626ab-0365-4034-82b6-2a58d36fbc94"
  }
}

# Create a NAT Gateway for each public subnet of the Internet-Egress VPC
resource "aws_nat_gateway" "Internet-Egress" {
  for_each = local.Internet-Egress_NATGW_subnets
  allocation_id = aws_eip.NATgw[each.key].id # the Allocation ID of the elastic IP address
  subnet_id = aws_subnet.Internet-Egress_NATGW[each.key].id # the NAT gateway will be placed in the public subnet

  tags = {
    "Name" = "VPC-${each.value.vpc}-NATgw-${each.value.az}"
    "Project ID" = "b21626ab-0365-4034-82b6-2a58d36fbc94"
  }
}

# Create an Internet Gateway for the Internet-Egress VPC
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.Internet-Egress.id
  
  tags = {
    "Name" = "igw"
    "Project ID" = "b21626ab-0365-4034-82b6-2a58d36fbc94"
  }
}

# Create a route table for each Transit Gateway subnet in Internet-Egress VPC
resource "aws_route_table" "Internet-Egress_TGW" {
  for_each = local.Internet-Egress_TGW_subnets
  vpc_id = aws_vpc.Internet-Egress.id

  route {
    cidr_block = "10.0.0.0/15" # to Spoke-1 and Spoke-2 VPCs (summarized)
    transit_gateway_id = aws_ec2_transit_gateway.TGW1.id
  }

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.Internet-Egress[local.Internet-Egress_TGW_NATGW_map[each.key]].id
  }

  tags = {
    "Name" = "VPC-${each.value.vpc}-TGW-rt-${each.value.az}"
    "Project ID" = "b21626ab-0365-4034-82b6-2a58d36fbc94"
  }
}

# Create a route table association to associate each "Internet-Egress_TGW" route table to each Transit Gateway subnet for Internet-Egress VPC
resource "aws_route_table_association" "Internet-Egress_TGW" {
  for_each = aws_subnet.Internet-Egress_TGW
  route_table_id = aws_route_table.Internet-Egress_TGW[each.key].id
  subnet_id = each.value.id
}

# Create a route table for each public subnet (containing a NAT Gateway) in Internet-Egress VPC
resource "aws_route_table" "Internet-Egress_NATGW" {
  for_each = local.Internet-Egress_NATGW_subnets
  vpc_id = aws_vpc.Internet-Egress.id

  route {
    cidr_block = "10.0.0.0/15" # to Spoke-1 and Spoke-2 VPCs (summarized)
    transit_gateway_id = aws_ec2_transit_gateway.TGW1.id
  }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    "Name" = "VPC-${each.value.vpc}-NATGW-rt-${each.value.az}"
    "Project ID" = "b21626ab-0365-4034-82b6-2a58d36fbc94"
  }
}

# Create a route table association to associate each "Internet-Egress_NATGW" route table to each public subnet (containing a NAT Gateway) for Internet-Egress VPC
resource "aws_route_table_association" "Internet-Egress_NATGW" {
  for_each = aws_subnet.Internet-Egress_NATGW
  route_table_id = aws_route_table.Internet-Egress_NATGW[each.key].id
  subnet_id = each.value.id
}

# Associate Transit Gateway Route Table "Egress" with AWS Transit Gateway attachments in Internet-Egress VPC
resource "aws_ec2_transit_gateway_route_table_association" "Internet-Egress" {
  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.Internet-Egress.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.Egress.id
}