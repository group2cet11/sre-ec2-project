bucket         = "sre-tf-backend-uat"
key            = "ec2/uat/terraform.tfstate"
region         = "us-east-1"
encrypt        = true
dynamodb_table = "terraform-locks"
