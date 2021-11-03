# Create and configure interface and gateway VPC endpoints for AWS Systems Manager

## Prerequisites
Follow the steps described in "Setting up AWS Systems Manager for EC2 instances" at https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-setting-up-ec2.html.

## Architecture Diagram
![VPC_endpoints_for_AWS_SSM](./Pictures/Systems_Manager_VPC_endpoints.png)

## Goal
Connect remotely to the EC2 instance using AWS Systems Manager Session Manager *without* having to use an internet gateway, a public IPv4 address assigned to one of the elastic network interfaces of the EC2 instance, and a security group rule that allows port 22 inbound traffic.

## Tasks
- Create a Virtual Private Cloud (VPC)
- Create a private subnet
- Create a VPC Route Table for the "private" subnet
- Associate the "private" route table with the "private" subnet
- Create a gateway VPC endpoint
- Create an Amazon S3 bucket and create a bucket policy
- Block public access to the S3 bucket
- Create a security group for the EC2 instance(s)
- Create a launch template and specify the security group 
- Create an EC2 instance from the launch template and attach an IAM instance profile named "AmazonSSMManagedInstanceCore" to the instance
- Create a security group for the interface VPC endpoints
- Create the interface VPC endpoints

## Links
AWS Systems Manager VPC endpoints documentation: https://docs.aws.amazon.com/systems-manager/latest/userguide/setup-create-vpc.html