# module "ecr" {
#   source = "../../resource_modules/container/ecr"

#   ## ECR repo ##
#   name                 = var.ecr_name
#   image_tag_mutability = var.ecr_image_tag_mutability
#   tags                 = var.ecr_tags

#   ## ECR repo policy ##
#   ecr_repo_policy = var.ecr_repo_policy

#   ## ECR lifecycle policy ##
#   ecr_lifecycle_policy = var.ecr_lifecycle_policy
# }

module "key_pair" {
  source = "../../resource_modules/compute/ec2_key_pair"

  key_name   = local.key_pair_name
  public_key = local.public_key
}

# ref: https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/examples/basic/main.tf#L125-L160
module "eks_cluster" {
  source = "../../resource_modules/container/eks"

  create_eks      = var.create_eks
  cluster_version = var.cluster_version
  cluster_name    = var.cluster_name
  kubeconfig_name = var.cluster_name
  vpc_id          = var.vpc_id
  subnets         = var.subnets

  worker_groups                        = var.worker_groups
  node_groups                          = var.node_groups
  worker_additional_security_group_ids = var.worker_additional_security_group_ids

  map_roles                                  = var.map_roles
  # map_users                                  = var.map_users
  kubeconfig_aws_authenticator_env_variables = var.kubeconfig_aws_authenticator_env_variables

  enable_irsa                   = var.enable_irsa
  cluster_enabled_log_types     = var.enabled_cluster_log_types
  cluster_log_retention_in_days = var.cluster_log_retention_in_days

  key_name = module.key_pair.key_name

  # use KMS key to encrypt EKS worker node's root EBS volumes
  root_kms_key_id = module.eks_node_ebs_kms_key.arn

  # need to attach ASG IAM policy to node's IAM instance profile IF cluster autoscaler isn't using IRSA (IAM role for service account per pod)
  # workers_additional_policies = [module.cluster_autoscaler_iam_policy.arn]

  # add AWS managed SSM IAM policy
  # workers_additional_policies = [
  #   data.aws_iam_policy.ssm_for_ec2.arn,
  #   data.aws_iam_policy.ssm_full_access_policy.arn,
  # ]

  # WARNING: changing this will force recreating an entire EKS cluster!!!
  # enable k8s secret encryption using AWS KMS. Ref: https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/examples/secrets_encryption/main.tf#L88
  cluster_encryption_config = [
    {
      provider_key_arn = module.k8s_secret_kms_key.arn
      resources        = ["secrets"]
    }
  ]

  tags = var.tags
}

# IRSA ##
module "cluster_autoscaler_iam_assumable_role" {
  source = "../../resource_modules/identity/iam/iam-assumable-role-with-oidc"

  create_role                   = var.create_eks ? true : false
  role_name                     = local.cluster_autoscaler_iam_role_name
  provider_url                  = replace(module.eks_cluster.cluster_oidc_issuer_url, "https://", "")
  role_policy_arns              = [module.cluster_autoscaler_iam_policy.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:${var.cluster_autoscaler_service_account_namespace}:${var.cluster_autoscaler_service_account_name}"]
}

module "cluster_autoscaler_iam_policy" {
  source = "../../resource_modules/identity/iam/policy"

  create_policy = var.create_eks ? true : false
  description   = local.cluster_autoscaler_iam_policy_description
  name          = local.cluster_autoscaler_iam_policy_name
  path          = local.cluster_autoscaler_iam_policy_path
  policy        = data.aws_iam_policy_document.cluster_autoscaler.json
}

## test_irsa_iam_assumable_role ##
module "test_irsa_iam_assumable_role" {
  source = "../../resource_modules/identity/iam/iam-assumable-role-with-oidc"

  create_role  = var.create_eks ? true : false
  role_name    = local.test_irsa_iam_role_name
  provider_url = replace(module.eks_cluster.cluster_oidc_issuer_url, "https://", "")
  role_policy_arns = [
    data.aws_iam_policy.s3_read_only_access_policy.arn # <------- reference AWS Managed IAM policy ARN
  ]
  oidc_fully_qualified_subjects = ["system:serviceaccount:${var.test_irsa_service_account_namespace}:${var.test_irsa_service_account_name}"]
}

########################################
## KMS for EKS node's EBS volume
########################################
module "eks_node_ebs_kms_key" {
  source = "../../resource_modules/identity/kms_key"

  name                    = local.eks_node_ebs_kms_key_name
  description             = local.eks_node_ebs_kms_key_description
  deletion_window_in_days = local.eks_node_ebs_kms_key_deletion_window_in_days
  tags                    = local.eks_node_ebs_kms_key_tags
  policy                  = data.aws_iam_policy_document.ebs_decryption.json
  enable_key_rotation     = true
}

# ########################################
# ## KMS for K8s secret's DEK (data encryption key) encryption
# ########################################
module "k8s_secret_kms_key" {
  source = "../../resource_modules/identity/kms_key"

  name                    = local.k8s_secret_kms_key_name
  description             = local.k8s_secret_kms_key_description
  deletion_window_in_days = local.k8s_secret_kms_key_deletion_window_in_days
  tags                    = local.k8s_secret_kms_key_tags
  policy                  = data.aws_iam_policy_document.k8s_api_server_decryption.json
  enable_key_rotation     = true
}