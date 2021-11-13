terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.57.0" # allows only rightmost version component to increment
    }
  }
  required_version = ">= 1.0.0" # only Terraform version 1.0.0 or greater can be used with this configuration
}