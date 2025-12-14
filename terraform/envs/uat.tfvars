# envs/uat.tfvars (updated)
environment         = "uat"
region              = "us-east-1"
instance_type       = "t3.micro"
userdata_revision   = 2
key_name            = "dave-key"
subnet_id           = "subnet-0eac7bd1ef91ab150"  # Use same or different subnet for uat
vpc_id              = "vpc-0e76ad8a9fd3d2633"
project             = "sre"
