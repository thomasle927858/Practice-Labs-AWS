variable "AWS_account_ID" {} # (obviously, do not expose this to unauthorized personnel)
variable "vpc_security_group_IDs" {} # this variable may also be considered as sensitive; it will not be used in this example
variable "index_0_security_groups" {} # this variable may also be considered as sensitive
variable "index_0_subnet_ID" {} # this variable may also be considered as sensitive

provider "aws" {
  region = "us-west-1"
  # authentication
  # shared_credentials_file = "/enter/path/to/file"
  # profile = "whatever_custom_profile"
  # AWS profile name as set in the shared credentials file
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
  instance_market_options {
    market_type = "spot" # spot market
    spot_options {
      instance_interruption_behavior = "terminate" # what occurs when a Spot Instance is interrupted
      max_price = 0.004 # the maximum hourly price you will pay for Spot Instance(s)
      spot_instance_type = "one-time" # Spot request will not be opened again after the Spot Instance is interrupted or you stop the Spot Instance
    }
  }
  instance_type = "t3.micro"
  monitoring {
    enabled = false # detailed monitoring disabled for the launched EC2 instance
  }
  name = "Amazon_Linux_2_launch_template_Sep_2021"
  network_interfaces {
    description = "example network interface"
    device_index = 0
    security_groups = var.index_0_security_groups  # collection type set of str
    subnet_id = var.index_0_subnet_ID # type str
  }
  tag_specifications {
    resource_type = "instance"
    tags = {
      "Project ID" = "2"
    }
  }
  # vpc_security_group_ids = var.vpc_security_group_IDs # conflicts with security_groups in network_interfaces block
}
# EC2 Spot Fleet Request
resource "aws_spot_fleet_request" "example_1" {
  iam_fleet_role  = "arn:aws:iam::${var.AWS_account_ID}:role/aws-ec2-spot-fleet-tagging-role" # see https://docs.aws.amazon.com/general/latest/gr/aws-arns-and-namespaces.html for Amazon Resource Name format 
  fleet_type = "request"
  launch_template_config {
    launch_template_specification {
      id      = aws_launch_template.Amazon_Linux_2.id
      version = aws_launch_template.Amazon_Linux_2.latest_version
    }
  }
  spot_price = "0.0045" # maximum bid price per hour (type is string)
  target_capacity = 2 # number of units to request
  valid_until = "2021-09-25T23:59:59Z" # date and time string formatted in accordance with RFC 3339
}