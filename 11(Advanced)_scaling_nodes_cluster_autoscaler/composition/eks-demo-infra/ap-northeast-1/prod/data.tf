locals {
  tags = {
    Environment = var.env
    Application = var.app_name
    Terraform   = true
  }

  ########################################
  # VPC
  ########################################
  vpc_name = "vpc-${var.region_tag[var.region]}-${var.env}-${var.app_name}"
  vpc_tags = merge(
    local.tags,
    tomap({
        "VPC-Name" = local.vpc_name
    })
  )

  # add three ingress rules from EKS worker SG to DB SG only when creating EKS cluster
  databse_computed_ingress_with_eks_worker_source_security_group_ids = var.create_eks ? [
    {
      rule                     = "mongodb-27017-tcp"
      source_security_group_id = module.eks.worker_security_group_id
      description              = "mongodb-27017 from EKS SG in private subnet"
    },
    {
      rule                     = "mongodb-27018-tcp"
      source_security_group_id = module.eks.worker_security_group_id
      description              = "mongodb-27018 from EKS SG in private subnet"

    },
    {
      rule                     = "mongodb-27019-tcp"
      source_security_group_id = module.eks.worker_security_group_id
      description              = "mongodb-27019 from EKS SG in private subnet"
    }
  ] : []


  ########################################
  # EKS
  ########################################
  ## ECR ##
  # ecr_name = "ecr-${var.region_tag[var.region]}-${var.env}-peerwell-api"
  # ecr_tags = merge(
  #   local.tags,
  #   map("ECR-Name", local.ecr_name)
  # )

  ## EKS ##
  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.private_subnets
  cluster_name    = "eks-${var.region_tag[var.region]}-${var.env}-${var.app_name}"

  # note: "shared" tag needed for EKS to find VPC subnets by tags. Ref: https://docs.aws.amazon.com/eks/latest/userguide/network_reqs.html
  eks_tags = {
    Environment                                       = var.env
    Application                                       = var.app_name
    "kubernetes.io/cluster/${local.cluster_name}"     = "shared"
    "k8s.io/cluster-autoscaler/${local.cluster_name}" = "true"
  }

  map_roles = var.authenticate_using_role == true ? concat(var.map_roles, [
    {
      rolearn  = "arn:aws:iam::${data.aws_caller_identity.this.account_id}:role/${var.role_name}"
      username = "k8s_terraform_builder"
      groups   = ["system:masters"]
    },
    {
      rolearn  = "arn:aws:iam::${data.aws_caller_identity.this.account_id}:role/Developer"
      username = "k8s-developer"
      groups   = ["k8s-developer"]
    },
  ]) : var.map_roles

  # specify AWS Profile if you want kubectl to use a named profile to authenticate instead of access key and secret access key
  kubeconfig_aws_authenticator_env_variables = var.authenticate_using_aws_profile == true ? {
    AWS_PROFILE = var.profile_name
  } : {}

  # ## EFS ##
  # efs_mount_target_subnet_ids   = module.vpc.private_subnets
  # efs_mount_target_subnet_count = length(module.vpc.private_subnets)
}

data "aws_caller_identity" "this" {}

# if you leave default value of "manage_aws_auth = true" then you need to configure the kubernetes provider as per the doc: https://github.com/terraform-aws-modules/terraform-aws-eks/blob/v12.1.0/README.md#conditional-creation, https://github.com/terraform-aws-modules/terraform-aws-eks/issues/911
data "aws_eks_cluster" "cluster" {
  count = var.create_eks ? 1 : 0
  name  = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  count = var.create_eks ? 1 : 0
  name  = module.eks.cluster_id
}