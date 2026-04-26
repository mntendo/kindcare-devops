terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # S3 backend for storing Terraform state
  # We will create this S3 bucket manually once before running terraform
  backend "s3" {
    bucket         = "kindcare-terraform-state"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "kindcare-terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region
}

# CALL THE VPC MODULE
module "vpc" {
  source = "../../modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = "10.0.0.0/16"
  availability_zones   = ["us-east-1a", "us-east-1b"]
  private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24"]
}

# CALL THE EKS MODULE
# Notice we pass VPC outputs directly into EKS inputs
module "eks" {
  source = "../../modules/eks"

  project_name       = var.project_name
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids
  node_instance_type = "t3.medium"
  node_desired_size  = 2
  node_min_size      = 1
  node_max_size      = 3
  kubernetes_version = "1.29"
}

# CALL THE RDS MODULE
# Notice we pass VPC and EKS outputs into RDS inputs
module "rds" {
  source = "../../modules/rds"

  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  db_name               = "kindcare"
  db_username           = "kindcare"
  db_password           = var.db_password
  db_instance_class     = "db.t3.micro"
  eks_security_group_id = module.eks.cluster_security_group_id
}