terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.70"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

terraform {
  required_version = "~> 1.0"
}


### Backend ###
# S3
###############

terraform {
  backend "s3" {
    bucket         = "cloudgeeks-terraform"
    key            = "env/dev/cloudgeeks-dev.tfstate"
    region         = "us-east-1"
   # dynamodb_table = "cloudgeeks-dev-terraform-backend-state-lock"
  }
}

#########
# Eks Vpc
#########
module "eks_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.11.0"

  name            = var.cluster_name

  cidr            = "10.60.0.0/16"
  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.60.0.0/23", "10.60.2.0/23", "10.60.4.0/23"]
  public_subnets  = ["10.60.100.0/23", "10.60.102.0/24", "10.60.104.0/24"]


  map_public_ip_on_launch = true
  enable_nat_gateway      = true
  single_nat_gateway      = true
  one_nat_gateway_per_az  = false

  create_database_subnet_group           = true
  create_database_subnet_route_table     = true
  create_database_internet_gateway_route = false
  create_database_nat_gateway_route      = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }

}



#############
# Eks Cluster
#############
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "17.24.0"

  cluster_version           = "1.21"
  cluster_name              = "cloudgeeks-eks-dev"
  vpc_id                    = module.eks_vpc.vpc_id
  subnets                   = module.eks_vpc.private_subnets
  create_eks                = true
  manage_aws_auth           = true
  write_kubeconfig          = true
  kubeconfig_output_path    = "/root/.kube/config" # touch /root/.kube/config
  kubeconfig_name           = "config"
  enable_irsa               = true                 # oidc
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

# https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/17.21.0/submodules/node_groups
  node_groups = {
    cloudgeeks-eks-workers = {
      create_launch_template = true
      name                   = "cloudgeeks-eks-workers"  # Eks Workers Node Groups Name
      instance_types         = ["t3a.medium"]
      capacity_type          = "ON_DEMAND"
      desired_capacity       = 1
      max_capacity           = 1
      min_capacity           = 1
      disk_type              = "gp2"
      disk_size              = 20
      ebs_optimized          = true
      disk_encrypted         = true
      key_name               = "terraform-cloudgeeks"
      enable_monitoring      = true

      additional_tags = {
        Name = "eks-worker"                            # Tags for Cluster Worker Nodes
      }

    }
  }


}