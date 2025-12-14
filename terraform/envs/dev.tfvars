# envs/dev.tfvars (updated with required variables)
environment         = "dev"
region              = "us-east-1"
instance_type       = "t3.micro"
userdata_revision   = 3
key_name            = "dave-key"
subnet_id           = "subnet-0eac7bd1ef91ab150"  # Replace with your actual public subnet ID for dev
vpc_id              = "vpc-0e76ad8a9fd3d2633"     # Your VPC ID
project             = "sre"
ami_id              = "ami-0c101f26f147fa7fd"    # Optional - override if needed
