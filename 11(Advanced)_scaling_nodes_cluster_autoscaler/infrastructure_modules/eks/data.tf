locals {
  ## Key Pair ##
  key_pair_name = "eks-workers-keypair-${var.region_tag[var.region]}-${var.env}-${var.app_name}"
  public_key    = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC+6hyhXItMXzNI/P481x2BsIU2VEVE4N2ET43GMxr1y+Hufa58BIzd0I7JuForq8kufhx2PhWnlD6wj6YKYti5qu4nvaKbVABYtzO0QN6SLo48kvmdwX4UF+QLO/YoBau/czq1zgxZ18F3kQ/Z0rdy11O7tU7dRDUGvpCNL8G+Qkadwt39AIXd3923GMtB8TxjWN4HeKLD9VGDOyD9WgmIwuC8/hJhej9AaqA/zKDcgune8ZPv8AQ7STzKNynnKaGjzpZPeY9xvPBsNEZjCJsKt3XBQGd+Hz3DtmGrsCMAbF5FUdZll5fzgZK46zwXnRRp2XjUEfUJyoLhaaay1Yvd hasakura@Hisashis-MBP.w.mifi"

  ## cluster_autoscaler_iam_role ##
  cluster_autoscaler_iam_role_name = "EKSClusterAutoscaler"

  ## cluster_autoscaler_iam_policy ##
  cluster_autoscaler_iam_policy_description = "EKS cluster-autoscaler policy for cluster ${module.eks_cluster.cluster_id}"
  cluster_autoscaler_iam_policy_name        = "${local.cluster_autoscaler_iam_role_name}Policy"
  cluster_autoscaler_iam_policy_path        = "/"

  ## test_irsa_iam_assumable_role ##
  test_irsa_iam_role_name = "TestIrsaS3ReadOnlyRole"

  ########################################
  ##  KMS for EKS node's EBS volume
  ########################################
  eks_node_ebs_kms_key_name                    = "alias/cmk-${var.region_tag[var.region]}-${var.env}-eks-node-ebs-volume"
  eks_node_ebs_kms_key_description             = "Kms key used for EKS node's EBS volume"
  eks_node_ebs_kms_key_deletion_window_in_days = "30"
  eks_node_ebs_kms_key_tags = merge(
    var.tags,
    tomap({
        "Name" = local.eks_node_ebs_kms_key_name
    })
  )

  ########################################
  ##  KMS for K8s secret's DEK (data encryption key) encryption
  ########################################
  k8s_secret_kms_key_name                    = "alias/cmk-${var.region_tag[var.region]}-${var.env}-k8s-secret-dek"
  k8s_secret_kms_key_description             = "Kms key used for encrypting K8s secret DEK (data encryption key)"
  k8s_secret_kms_key_deletion_window_in_days = "30"
  k8s_secret_kms_key_tags = merge(
    var.tags,
    tomap({
        "Name" = local.k8s_secret_kms_key_name
    })
  )
}

# current account ID
data "aws_caller_identity" "this" {}

# ref: https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/examples/irsa/irsa.tf
data "aws_iam_policy_document" "cluster_autoscaler" {
  statement {
    sid    = "clusterAutoscalerAll"
    effect = "Allow"

    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeTags",
      "ec2:DescribeLaunchTemplateVersions",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "clusterAutoscalerOwn"
    effect = "Allow"

    actions = [
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
      "autoscaling:UpdateAutoScalingGroup",
    ]

    resources = ["*"]

    # limit who can assume the role
    # ref: https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts-technical-overview.html
    # ref: https://www.terraform.io/docs/providers/aws/r/eks_cluster.html#enabling-iam-roles-for-service-accounts

    # [FIXED by using correct tag] ISSUE with below: SetDesiredCapacity operation: User: arn:aws:sts::202536423779:assumed-role/EKSClusterAutoscaler/botocore-session-1588872862 is not authorized to perform: autoscaling:SetDesiredCapacity on resource: arn:aws:autoscaling:us-east-1:202536423779:autoScalingGroup:b44f55c0-a6a9-4689-8651-7a72b7c6300a:autoScalingGroupName/eks-ue1-prod-peerwell-api-infra-worker-group-staging-120200507173038542300000005
    condition {
      test     = "StringEquals"
      variable = "autoscaling:ResourceTag/kubernetes.io/cluster/${module.eks_cluster.cluster_id}"
      values   = ["shared"]
    }

    condition {
      test     = "StringEquals"
      variable = "autoscaling:ResourceTag/k8s.io/cluster-autoscaler/enabled"
      values   = ["true"]
    }
  }
}

data "aws_iam_policy" "s3_read_only_access_policy" {
  arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

# ref: https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/examples/launch_templates_with_managed_node_groups/disk_encryption_policy.tf
# This policy is required for the KMS key used for EKS root volumes, so the cluster is allowed to enc/dec/attach encrypted EBS volumes
data "aws_iam_policy_document" "ebs_decryption" {
  # Copy of default KMS policy that lets you manage it
  statement {
    sid    = "Allow access for Key Administrators"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.this.account_id}:root"]
    }

    actions = [
      "kms:*"
    ]

    resources = ["*"]
  }

  # Required for EKS
  statement {
    sid    = "Allow service-linked role use of the CMK"
    effect = "Allow"

    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.this.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling", # required for the ASG to manage encrypted volumes for nodes
        module.eks_cluster.cluster_iam_role_arn,
        "arn:aws:iam::${data.aws_caller_identity.this.account_id}:root", # required for the cluster / persistentvolume-controller to create encrypted PVCs
      ]
    }

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "Allow attachment of persistent resources"
    effect = "Allow"

    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.this.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling", # required for the ASG to manage encrypted volumes for nodes
        module.eks_cluster.cluster_iam_role_arn,                                                                                                 # required for the cluster / persistentvolume-controller to create encrypted PVCs
      ]
    }

    actions = [
      "kms:CreateGrant"
    ]

    resources = ["*"]

    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }

  }
}

data "aws_iam_policy_document" "k8s_api_server_decryption" {
  # Copy of default KMS policy that lets you manage it
  statement {
    sid    = "Allow access for Key Administrators"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.this.account_id}:root"]
    }

    actions = [
      "kms:*"
    ]

    resources = ["*"]
  }

  # Required for EKS
  statement {
    sid    = "Allow service-linked role use of the CMK"
    effect = "Allow"

    principals {
      type = "AWS"
      identifiers = [
        module.eks_cluster.cluster_iam_role_arn, # required for the cluster / persistentvolume-controller
        "arn:aws:iam::${data.aws_caller_identity.this.account_id}:root", 
      ]
    }

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "Allow attachment of persistent resources"
    effect = "Allow"

    principals {
      type = "AWS"
      identifiers = [
        module.eks_cluster.cluster_iam_role_arn,                                                                                                 # required for the cluster / persistentvolume-controller to create encrypted PVCs
      ]
    }

    actions = [
      "kms:CreateGrant"
    ]

    resources = ["*"]

    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }
}