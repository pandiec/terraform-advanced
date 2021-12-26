########################################
# VPC
########################################
module "vpc" {
  source = "../../../../infrastructure_modules/vpc" # using infra module VPC which acts like a facade to many sub-resources

  name                 = var.app_name
  cidr                 = var.cidr
  azs                  = var.azs
  private_subnets      = var.private_subnets
  public_subnets       = var.public_subnets
  database_subnets     = var.database_subnets
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support
  enable_nat_gateway   = var.enable_nat_gateway
  single_nat_gateway   = var.single_nat_gateway

  ## Public Security Group ##
  public_ingress_with_cidr_blocks = var.public_ingress_with_cidr_blocks

  ## Private Security Group ##
  # bastion EC2 not created yet
  # bastion_sg_id  = module.bastion.security_group_id

  ## Database security group ##
  # DB Controller EC2 not created yet
  # databse_computed_ingress_with_db_controller_source_security_group_id = module.db_controller_instance.security_group_id
  create_eks                                                           = var.create_eks
  # pass EKS worker SG to DB SG after creating EKS module at composition layer
  databse_computed_ingress_with_eks_worker_source_security_group_ids   = local.databse_computed_ingress_with_eks_worker_source_security_group_ids

  # cluster_name = local.cluster_name

  ## Common tag metadata ##
  env      = var.env
  app_name = var.app_name
  tags     = local.vpc_tags
  region   = var.region
}

########################################
# EKS
########################################
module "eks" {
  source = "../../../../infrastructure_modules/eks"

  ## EKS ##
  create_eks      = var.create_eks
  cluster_version = var.cluster_version
  cluster_name    = local.cluster_name
  vpc_id          = local.vpc_id
  subnets         = local.private_subnets

  # note: either pass worker_groups or node_groups
  # this is for (EKSCTL API) unmanaged node group
  worker_groups = var.worker_groups

  # this is for (EKS API) managed node group
  node_groups = var.node_groups

  # worker_additional_security_group_ids = [data.aws_security_group.client_vpn_sg.id]

  # add roles that can access K8s cluster
  map_roles = local.map_roles

  # specify AWS Profile if you want kubectl to use a named profile to authenticate instead of access key and secret access key
  kubeconfig_aws_authenticator_env_variables = local.kubeconfig_aws_authenticator_env_variables

  ## IRSA (IAM role for service account) ##
  enable_irsa                                  = var.enable_irsa
  test_irsa_service_account_namespace                = "default"
  test_irsa_service_account_name                     = "test-irsa"
  cluster_autoscaler_service_account_namespace = var.cluster_autoscaler_service_account_namespace
  cluster_autoscaler_service_account_name      = var.cluster_autoscaler_service_account_name

  enabled_cluster_log_types     = var.enabled_cluster_log_types
  cluster_log_retention_in_days = var.cluster_log_retention_in_days

  ## EFS SG ##
  vpc_cidr_block = module.vpc.vpc_cidr_block

  ## EFS ## 
  efs_mount_target_subnet_ids = module.vpc.private_subnets

  ## Common tag metadata ##
  env             = var.env
  app_name        = var.app_name
  tags            = local.eks_tags
  region          = var.region
}