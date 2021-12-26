locals {
  ## Key Pair ##
  key_pair_name = "eks-workers-keypair-${var.region_tag[var.region]}-${var.env}-${var.app_name}"
  public_key    = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC+6hyhXItMXzNI/P481x2BsIU2VEVE4N2ET43GMxr1y+Hufa58BIzd0I7JuForq8kufhx2PhWnlD6wj6YKYti5qu4nvaKbVABYtzO0QN6SLo48kvmdwX4UF+QLO/YoBau/czq1zgxZ18F3kQ/Z0rdy11O7tU7dRDUGvpCNL8G+Qkadwt39AIXd3923GMtB8TxjWN4HeKLD9VGDOyD9WgmIwuC8/hJhej9AaqA/zKDcgune8ZPv8AQ7STzKNynnKaGjzpZPeY9xvPBsNEZjCJsKt3XBQGd+Hz3DtmGrsCMAbF5FUdZll5fzgZK46zwXnRRp2XjUEfUJyoLhaaay1Yvd hasakura@Hisashis-MBP.w.mifi"

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