bucket         = "sre-tf-backend-dev-108471662249"
key            = "ec2/${terraform.workspace}/terraform.tfstate"
region         = "us-east-1"
encrypt        = true
dynamodb_table = "terraform-locks"
