## EKS ##
output "cluster_name" {
  description = "The name of the EKS cluster."
  value       = module.eks_cluster.cluster_id
}

output "cluster_id" {
  description = "The id of the EKS cluster."
  value       = module.eks_cluster.cluster_id
}

output "cluster_arn" {
  description = "The Amazon Resource Name (ARN) of the cluster."
  value       = module.eks_cluster.cluster_arn
}

output "cluster_certificate_authority_data" {
  description = "Nested attribute containing certificate-authority-data for your cluster. This is the base64 encoded certificate data required to communicate with your cluster."
  value       = module.eks_cluster.cluster_certificate_authority_data
}

output "cluster_endpoint" {
  description = "The endpoint for your EKS Kubernetes API."
  value       = module.eks_cluster.cluster_endpoint
}

output "cluster_version" {
  description = "The Kubernetes server version for the EKS cluster."
  value       = module.eks_cluster.cluster_version
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster."
  value       = module.eks_cluster.cluster_security_group_id
}

output "config_map_aws_auth" {
  description = "A kubernetes configuration to authenticate to this EKS cluster."
  value       = module.eks_cluster.config_map_aws_auth
}

output "cluster_iam_role_name" {
  description = "IAM role name of the EKS cluster."
  value       = module.eks_cluster.cluster_iam_role_name
}

output "cluster_iam_role_arn" {
  description = "IAM role ARN of the EKS cluster."
  value       = module.eks_cluster.cluster_iam_role_arn
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster OIDC Issuer"
  value       = module.eks_cluster.cluster_oidc_issuer_url
}

output "cloudwatch_log_group_name" {
  description = "Name of cloudwatch log group created"
  value       = module.eks_cluster.cloudwatch_log_group_name
}

output "kubeconfig" {
  description = "kubectl config file contents for this EKS cluster."
  value       = module.eks_cluster.kubeconfig
}

output "kubeconfig_filename" {
  description = "The filename of the generated kubectl config."
  value       = module.eks_cluster.kubeconfig_filename
}

output "workers_asg_arns" {
  description = "IDs of the autoscaling groups containing workers."
  value       = module.eks_cluster.workers_asg_arns
}

output "workers_asg_names" {
  description = "Names of the autoscaling groups containing workers."
  value       = module.eks_cluster.workers_asg_names
}

output "workers_user_data" {
  description = "User data of worker groups"
  value       = module.eks_cluster.workers_user_data
}

output "workers_default_ami_id" {
  description = "ID of the default worker group AMI"
  value       = module.eks_cluster.workers_default_ami_id
}

output "workers_launch_template_ids" {
  description = "IDs of the worker launch templates."
  value       = module.eks_cluster.workers_launch_template_ids
}

output "workers_launch_template_arns" {
  description = "ARNs of the worker launch templates."
  value       = module.eks_cluster.workers_launch_template_arns
}

output "workers_launch_template_latest_versions" {
  description = "Latest versions of the worker launch templates."
  value       = module.eks_cluster.workers_launch_template_latest_versions
}

output "worker_security_group_id" {
  description = "Security group ID attached to the EKS workers."
  value       = module.eks_cluster.worker_security_group_id
}

output "worker_iam_instance_profile_arns" {
  description = "default IAM instance profile ARN for EKS worker groups"
  value       = module.eks_cluster.worker_iam_instance_profile_arns
}

output "worker_iam_instance_profile_names" {
  description = "default IAM instance profile name for EKS worker groups"
  value       = module.eks_cluster.worker_iam_instance_profile_names
}

output "worker_iam_role_name" {
  description = "default IAM role name for EKS worker groups"
  value       = module.eks_cluster.worker_iam_role_name
}

output "worker_iam_role_arn" {
  description = "default IAM role ARN for EKS worker groups"
  value       = module.eks_cluster.worker_iam_role_arn
}

output "node_groups" {
  description = "Outputs from EKS node groups. Map of maps, keyed by var.node_groups keys"
  value       = module.eks_cluster.node_groups
}

## IRSA ##
## cluster autoscale iam role ##
output "cluster_autoscaler_iam_assumable_role_arn" {
  description = "ARN of IAM role"
  value       = module.cluster_autoscaler_iam_assumable_role.arn
}

output "cluster_autoscaler_iam_assumable_role_name" {
  description = "Name of IAM role"
  value       = module.cluster_autoscaler_iam_assumable_role.name
}

output "cluster_autoscaler_iam_assumable_role_path" {
  description = "Path of IAM role"
  value       = module.cluster_autoscaler_iam_assumable_role.path
}

## cluster autoscale iam policy ##
output "cluster_autoscaler_iam_policy_id" {
  description = "The policy's ID."
  value       = module.cluster_autoscaler_iam_policy.id
}

output "cluster_autoscaler_iam_policy_arn" {
  description = "The ARN assigned by AWS to this policy."
  value       = module.cluster_autoscaler_iam_policy.arn
}

output "cluster_autoscaler_iam_policy_description" {
  description = "The description of the policy."
  value       = module.cluster_autoscaler_iam_policy.description
}

output "cluster_autoscaler_iam_policy_name" {
  description = "The name of the policy."
  value       = module.cluster_autoscaler_iam_policy.name
}

output "cluster_autoscaler_iam_policy_path" {
  description = "The path of the policy in IAM."
  value       = module.cluster_autoscaler_iam_policy.path
}

output "cluster_autoscaler_iam_policy" {
  description = "The policy document."
  value       = module.cluster_autoscaler_iam_policy.policy
}

########################################
# EFS MOUNT TARGET SG
########################################
output "efs_mount_target_security_group_id" {
  value = module.efs_security_group.this_security_group_id
}

output "efs_mount_target_security_group_vpc_id" {
  value = module.efs_security_group.this_security_group_vpc_id
}

output "efs_mount_target_security_group_name" {
  value = module.efs_security_group.this_security_group_name
}

########################################
# EFS
########################################
output "efs_id" {
  value = module.efs.efs_id
}

output "efs_arn" {
  value = module.efs.efs_arn
}

output "efs_dns_name" {
  value = module.efs.efs_dns_name
}

output "efs_mount_target_id" {
  value = module.efs.efs_mount_target_id
}

output "efs_mount_target_dns_name" {
  value = module.efs.efs_mount_target_dns_name
}

output "efs_mount_target_network_interface_id" {
  value = module.efs.efs_mount_target_network_interface_id
}