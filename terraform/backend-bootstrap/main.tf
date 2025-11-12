terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

variable "region" {
  type    = string
  default = "us-east-1"
}

# Names must match your backend.<env>.tfvars files
variable "bucket_names" {
  type = map(string)
  default = {
    dev  = "sre-tf-backend-dev"
    uat  = "sre-tf-backend-uat"
    prod = "sre-tf-backend-prod"
  }
}

# Single lock table shared by all envs
variable "lock_table_name" {
  type    = string
  default = "terraform-locks"
}

# --- S3 buckets (per env) ---
locals {
  envs = ["dev","uat","prod"]
}

resource "aws_s3_bucket" "tf" {
  for_each = toset(local.envs)
  bucket   = var.bucket_names[each.key]
}

resource "aws_s3_bucket_versioning" "tf" {
  for_each = aws_s3_bucket.tf
  bucket   = each.value.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf" {
  for_each = aws_s3_bucket.tf
  bucket   = each.value.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tf" {
  for_each                = aws_s3_bucket.tf
  bucket                  = each.value.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- DynamoDB table for state locking ---
resource "aws_dynamodb_table" "locks" {
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
