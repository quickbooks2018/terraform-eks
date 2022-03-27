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

#  Error: configmaps "aws-auth" already exists
#  Solution: kubectl delete configmap aws-auth -n kube-system

#########
# Eks Vpc
#########
module "eks_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.11.0"

  name            = var.cluster_name

  cidr             = "10.60.0.0/16"
  azs              = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets  = ["10.60.0.0/23", "10.60.2.0/23", "10.60.4.0/23"]
  public_subnets   = ["10.60.100.0/23", "10.60.102.0/24", "10.60.104.0/24"]
  database_subnets = ["10.60.200.0/24", "10.60.201.0/24", "10.60.202.0/24"]


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

# https://aws.amazon.com/premiumsupport/knowledge-center/eks-vpc-subnet-discovery/
  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"       = "1"
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
  manage_aws_auth           = false
  write_kubeconfig          = false
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


################
# Secret Manager
################
module "rds_secret" {
  source               = "../../modules/aws-secret-manager"
  namespace            = "cloudgeeks.ca"
  stage                = "dev"
  name                 = "rds-creds"
  secret-string         = {
    username             = "dbadmin"
    password             = var.rds-secret
    engine               = "mysql"
    host                 = module.rds-mysql.rds-end-point
    port                 = "3306"
    dbInstanceIdentifier = module.rds-mysql.rds-identifier
  }
  kms_key_id             = module.kms_rds-mysql_key.key_id
}

module "kms_rds-mysql_key" {
  source                  = "../../modules/aws-kms"
  namespace               = "cloudgeeks.ca"
  stage                   = "dev"
  name                    = "rds-mysql-key"
  alias                   = "alias/rds"
  deletion_window_in_days = "10"
}


###########
### RDS ##
############
module "rds-mysql" {
  source                                                           = "../../modules/aws-rds-mysql"
  namespace                                                        = "cloudgeeks.ca"
  stage                                                            = "dev"
  db-name                                                          = "mydb"
  rds-identifier                                                   = "mydb"
  final-snapshot-identifier                                        = "mydb-final-snap-shot"
  skip-final-snapshot                                              = "true"
  rds-allocated-storage                                            = "5"
  storage-type                                                     = "gp2"
  rds-engine                                                       = "mysql"
  engine-version                                                   = "5.7.17"
  db-instance-class                                                = "db.t2.micro"
  backup-retension-period                                          = "0"
  backup-window                                                    = "04:00-06:00"
  publicly-accessible                                              = "false"
  rds-username                                                     = "dbadmin"
  rds-password                                                     = var.rds-secret
  multi-az                                                         = "true"
  storage-encrypted                                                = "false"
  deletion-protection                                              = "false"
  vpc-security-group-ids                                           = [module.rds-sg.aws_security_group_default]
  db-subnet-group-name                                             = module.eks_vpc.database_subnet_group_name
}




#######################
### Security Groups ###
#######################
module "web-sg" {
  source              = "../../modules/aws-sg-cidr"
  namespace           = "cloudgeeks.ca"
  stage               = "dev"
  name                = "web"
  tcp_ports           = "80,443"
  cidrs               = ["0.0.0.0/0"]
  security_group_name = "websec"
  vpc_id              = module.eks_vpc.vpc_id
}


module "rds-sg" {
  source                  = "../../modules/aws-sg-ref-v2"
  namespace               = "cloudgeeks.ca"
  stage                   = "dev"
  name                    = "rds-sg"
  tcp_ports               = "3306"
  ref_security_groups_ids = [module.web-sg.aws_security_group_default]
  security_group_name     = "dbsec"
  vpc_id                  = module.eks_vpc.vpc_id
}
