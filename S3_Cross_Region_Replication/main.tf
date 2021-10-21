provider "aws" {
  region = "us-west-1"
  # authentication
  # shared_credentials_file = "/enter/path/to/file"
  # profile = "whatever_custom_profile"
  # AWS profile name as set in the shared credentials file
}

provider "aws" {
  alias = "us-west-1"
  region = "us-west-1"
}

provider "aws" {
  alias = "us-east-1"
  region = "us-east-1"
}

resource "aws_iam_role" "s3_replication" {
  name = "s3-replication-xxxx"
  path = "/s3/replication/test/"
  # trust policy for the role
  assume_role_policy = file("${path.module}/s3-replication-xxxx.json")

  tags = {
    "Name" = "example_role"
    "Project ID" = "08cced01-e5c5-444c-1111-a8cd5acd2fcf"
  }
}

resource "aws_iam_role_policy" "s3_replication_policy" {
  name = "s3_replication_policy"
  role = aws_iam_role.s3_replication.id
  # inline policy attached to the role
  policy = file("${path.module}/s3_replication_policy.json")
}

# create 2 S3 buckets in different regions for S3 Cross-Region Replication
resource "aws_s3_bucket" "destination" {
  provider = aws.us-east-1
  bucket = "6166c438-dd57-47c8-b738-528fa59d8ac4" # the name of the bucket
  # S3 bucket policy
  policy = file("${path.module}/bucket_policy_6166c438-dd57-47c8-b738-528fa59d8ac4.json")

  versioning {
    enabled = true # destination bucket must have versioning enabled for replication
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256" # SSE-S3 (server-side encryption with Amazon S3)
      }
    }
  }

  tags = {
    "Name" = "6166c438-dd57-47c8-b738-528fa59d8ac4"
    "Project ID" = "08cced01-e5c5-444c-1111-a8cd5acd2fcf"
  }
}

resource "aws_s3_bucket" "source" {
  provider = aws.us-west-1
  bucket = "95fdcd4e-f947-4519-b664-ffb9a47c9a49" # the name of the bucket
  # S3 bucket policy
  policy = file("${path.module}/bucket_policy_95fdcd4e-f947-4519-b664-ffb9a47c9a49.json")

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

  replication_configuration {
    role = aws_iam_role.s3_replication.arn # the Amazon Resource Name of the IAM role for Amazon S3 to assume

    rules {
      # filter object is optional (allows you to filter by prefix or tags)
      delete_marker_replication_status = "Enabled" # replicate delete markers
      id = "example1"
      status = "Enabled" # rule is enabled

      destination {
        bucket = aws_s3_bucket.destination.arn # the Amazon Resource Name of the destination S3 bucket
        storage_class = "STANDARD" # S3 Standard storage class
      }
    }
  }

  tags = {
    "Name" = "95fdcd4e-f947-4519-b664-ffb9a47c9a49"
    "Project ID" = "08cced01-e5c5-444c-1111-a8cd5acd2fcf"
  }
}

# apply Amazon S3 Block Public Access on the bucket level

resource "aws_s3_bucket_public_access_block" "destination" {
  provider = aws.us-east-1
  bucket = aws_s3_bucket.destination.id

  block_public_acls = true # Block public access to buckets and objects granted through new access control lists (ACLs)
  ignore_public_acls = true # Block public access to buckets and objects granted through any access control lists (ACLs)
  block_public_policy = true # Block public access to buckets and objects granted through new public bucket or access point policies
  restrict_public_buckets = true # Block public and cross-account access to buckets and objects through any public bucket or access point policies
}

resource "aws_s3_bucket_public_access_block" "source" {
  provider = aws.us-west-1
  bucket = aws_s3_bucket.source.id

  block_public_acls = true # Block public access to buckets and objects granted through new access control lists (ACLs)
  ignore_public_acls = true # Block public access to buckets and objects granted through any access control lists (ACLs)
  block_public_policy = true # Block public access to buckets and objects granted through new public bucket or access point policies
  restrict_public_buckets = true # Block public and cross-account access to buckets and objects through any public bucket or access point policies
}