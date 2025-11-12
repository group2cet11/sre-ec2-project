bucket         = "sre-tf-backend-prod"
key            = "ec2/prod/terraform.tfstate"
region         = "us-east-1"
encrypt        = true
dynamodb_table = "terraform-locks"
