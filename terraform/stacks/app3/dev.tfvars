environment  = "dev"
project_name = "app3"
domain_name  = "cloudconcious.dev"

# us-west-2 configuration
vpc_cidr_west            = "10.3.0.0/16"
public_subnet_cidrs_west = ["10.3.1.0/24"]
availability_zones_west  = ["us-west-2a"]
ami_id_west              = "ami-0c55b159cbfafe1f0" # Amazon Linux 2023 us-west-2

# us-east-1 configuration
vpc_cidr_east            = "10.4.0.0/16"
public_subnet_cidrs_east = ["10.4.1.0/24"]
availability_zones_east  = ["us-east-1a"]
ami_id_east              = "ami-0c55b159cbfafe1f0" # Amazon Linux 2023 us-east-1

instance_type = "t3.micro"
