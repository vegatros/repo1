# VPC Module
module "vpc" {
  source = "../../../../modules/network/vpc"

  project_name         = var.project_name
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  enable_nat_gateway   = true # EKS needs NAT for private subnets
  enable_flow_logs     = false

  tags = {
    Environment                                 = var.environment
    "kubernetes.io/cluster/${var.project_name}" = "shared"
  }
}

# EKS Module
module "eks" {
  source = "../../../../modules/eks"

  cluster_name           = var.project_name
  vpc_id                 = module.vpc.vpc_id
  subnet_ids             = module.vpc.private_subnet_ids
  instance_type          = var.instance_type
  desired_size           = var.desired_size
  min_size               = var.min_size
  max_size               = var.max_size
  admin_arns             = var.admin_arns
  enable_irsa            = true
  enable_cluster_logging = true
  cluster_log_types      = ["api", "audit", "authenticator"]

  tags = {
    Environment = var.environment
  }

  depends_on = [module.vpc]
}
