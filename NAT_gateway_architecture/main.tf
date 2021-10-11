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
    "Project ID" = "08cced01-e5c5-481c-98b8-a8cd5acd2fcf"
  }
}

# configure default network access control list (ACL) of the "example-01" VPC


# configure default security group of the "example-01" VPC
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.example-01.id
  
  egress = [
    {
      # (IPv4) CIDR blocks
      cidr_blocks = ["0.0.0.0/0"]
      # IPv6 CIDR blocks
      ipv6_cidr_blocks = []
      prefix_list_ids = [] # List of prefix list IDs (allow access to VPC endpoints)
      self = false # the security group itself will not be added as a source to this egress rule
      security_groups = [] # list of Security Group IDs if a VPC is used

      description = "Allow traffic to destination TCP port 80 (HTTP) and the destination IPv4 CIDR block 0.0.0.0/0"
      protocol = "tcp"
      # port range
      from_port = 80
      to_port = 80
      
    },
    {
      # (IPv4) CIDR blocks
      cidr_blocks = ["0.0.0.0/0"]
      # IPv6 CIDR blocks
      ipv6_cidr_blocks = []
      prefix_list_ids = [] # List of prefix list IDs (allow access to VPC endpoints)
      self = false # the security group itself will not be added as a source to this egress rule
      security_groups = [] # list of Security Group IDs if a VPC is used

      description = "Allow traffic to destination TCP port 443 (HTTPS) and the destination IPv4 CIDR block 0.0.0.0/0"
      protocol = "tcp"
      # port range
      from_port = 443
      to_port = 443
      
    }
  ]

  tags = {
    "Name" = "default"
    "Project ID" = "08cced01-e5c5-481c-98b8-a8cd5acd2fcf"
  }
}

# configure default network access control list of the "example-01" VPC
resource "aws_default_network_acl" "default" {
  default_network_acl_id = aws_vpc.example-01.default_network_acl_id
  
  
  # "Allow traffic from the source IPv4 CIDR block 0.0.0.0/0, with destination TCP ports 1024-65535, to the subnet"
  # This rule's intention is to allows inbound return IPv4 traffic from the internet for requests originally coming from the subnet (keep in mind network ACLs are stateless).
  ingress {
    rule_no = 100
    action = "allow"
    protocol = "tcp"
    # CIDR block
    cidr_block = "0.0.0.0/0"
    # port range (for NAT gateway); see https://docs.aws.amazon.com/vpc/latest/userguide/vpc-network-acls.html#nacl-ephemeral-ports
    from_port = 1024
    to_port = 65535
  }
  
  # "Allow traffic from the subnet to destination TCP port 80 (HTTP), to the destination IPv4 CIDR block 0.0.0.0/0"
  egress {
    rule_no = 100
    action = "allow"
    protocol = "tcp"
    # CIDR block
    cidr_block = "0.0.0.0/0"
    # port range
    from_port = 80
    to_port = 80
  }
  
  # "Allow traffic from the subnet to destination TCP port 443 (HTTPS), to the destination IPv4 CIDR block 0.0.0.0/0"
  egress {
    rule_no = 110
    action = "allow"
    protocol = "tcp"
    # CIDR block
    cidr_block = "0.0.0.0/0"
    # port range
    from_port = 443
    to_port = 443
  }

  tags = {
    "Name" = "default"
    "Project ID" = "08cced01-e5c5-481c-98b8-a8cd5acd2fcf"
  }
}

# Create Public Subnet
resource "aws_subnet" "public" {
  vpc_id = aws_vpc.example-01.id
  availability_zone = "us-west-1c"
  cidr_block = "172.16.2.0/24" # the IPv4 CIDR block for the subnet
  map_public_ip_on_launch = true # network interfaces created in this subnet should be assigned a public IP address
  assign_ipv6_address_on_creation = false # default, network interfaces created in this subnet should not be assigned an IPv6 address

  tags = {
    "Name" = "public"
    "Project ID" = "08cced01-e5c5-481c-98b8-a8cd5acd2fcf"
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
    "Project ID" = "08cced01-e5c5-481c-98b8-a8cd5acd2fcf"
  }
}

# Create network ACL and apply the network ACL to the "public" and "private" subnets
resource "aws_network_acl" "example-1" {
  vpc_id = aws_vpc.example-01.id # VPC ID
  subnet_ids = [aws_subnet.public.id, aws_subnet.private.id]

  ingress = [{
    # "Allow traffic from the source IPv4 CIDR block 0.0.0.0/0, with destination TCP ports 1024-65535, to the subnet"
    # This rule's intention is to allows inbound return IPv4 traffic from the internet for requests originally coming from the subnet (keep in mind network ACLs are stateless).
    rule_no = 100
    action = "allow"
    protocol = "tcp"
    # CIDR block
    cidr_block = "0.0.0.0/0"
    # IPv6 CIDR block
    ipv6_cidr_block = ""
    # port range (for NAT gateway); see https://docs.aws.amazon.com/vpc/latest/userguide/vpc-network-acls.html#nacl-ephemeral-ports
    from_port = 1024
    to_port = 65535
    icmp_type = null
    icmp_code = null
  }]

  egress = [{
    # "Allow traffic from the subnet to destination TCP port 80 (HTTP), to the destination IPv4 CIDR block 0.0.0.0/0"
    rule_no = 100
    action = "allow"
    protocol = "tcp"
    # CIDR block
    cidr_block = "0.0.0.0/0"
    # IPv6 CIDR block
    ipv6_cidr_block = ""
    # port range
    from_port = 80
    to_port = 80
    icmp_type = null
    icmp_code = null
  },
  {
    # "Allow traffic from the subnet to destination TCP port 443 (HTTPS), to the destination IPv4 CIDR block 0.0.0.0/0"
    rule_no = 110
    action = "allow"
    protocol = "tcp"
    # CIDR block
    cidr_block = "0.0.0.0/0"
    # IPv6 CIDR block
    ipv6_cidr_block = ""
    # port range
    from_port = 443
    to_port = 443
    icmp_type = null
    icmp_code = null
  }]

  tags = {
    "Name" = "example-1"
    "Project ID" = "08cced01-e5c5-481c-98b8-a8cd5acd2fcf"
  }
}

# Create a VPC Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.example-01.id
  
  tags = {
    "Name" = "igw"
    "Project ID" = "08cced01-e5c5-481c-98b8-a8cd5acd2fcf"
  }
}

# Create an Elastic IP for the public NAT Gateway
resource "aws_eip" "NATgw" {
  vpc = true # the Elastic IP is in a VPC

  tags = {
    "Name" = "NATgw"
    "Project ID" = "08cced01-e5c5-481c-98b8-a8cd5acd2fcf"
  }
}

# Create a public NAT Gateway
resource "aws_nat_gateway" "example1" {
  allocation_id = aws_eip.NATgw.id # the Allocation ID of the elastic IP address
  subnet_id = aws_subnet.public.id # the NAT gateway will be placed in the public subnet

  tags = {
    "Name" = "example1"
    "Project ID" = "08cced01-e5c5-481c-98b8-a8cd5acd2fcf"
  }
}

# Create a VPC Route Table for the "public" subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.example-01.id
  route = [
    {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.igw.id
      # processed in attributes-as-blocks mode
      ipv6_cidr_block = ""
      destination_prefix_list_id = ""
      carrier_gateway_id = ""
      egress_only_gateway_id = ""
      instance_id = ""
      local_gateway_id = ""
      nat_gateway_id = ""
      network_interface_id = ""
      transit_gateway_id = ""
      vpc_endpoint_id = ""
      vpc_peering_connection_id = ""
    }
  ]

  tags = {
    "Name" = "public"
    "Project ID" = "08cced01-e5c5-481c-98b8-a8cd5acd2fcf"
  }
}

# Create a VPC Route Table for the "private" subnet
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.example-01.id
  route = [
    {
      cidr_block = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.example1.id
      # processed in attributes-as-blocks mode
      ipv6_cidr_block = ""
      destination_prefix_list_id = ""
      carrier_gateway_id = ""
      egress_only_gateway_id = ""
      gateway_id = ""
      instance_id = ""
      local_gateway_id = ""
      network_interface_id = ""
      transit_gateway_id = ""
      vpc_endpoint_id = ""
      vpc_peering_connection_id = ""
    }
  ]

  tags = {
    "Name" = "private"
    "Project ID" = "08cced01-e5c5-481c-98b8-a8cd5acd2fcf"
  }
}

# Associate the "public" route table with the "public" subnet
resource "aws_route_table_association" "public" {
  route_table_id = aws_route_table.public.id
  subnet_id = aws_subnet.public.id
}

# Associate the "private" route table with the "private" subnet
resource "aws_route_table_association" "private" {
  route_table_id = aws_route_table.private.id
  subnet_id = aws_subnet.private.id
}
