# Auto Mount EFS to K8s Worker Nodes (EC2)

Ref: https://docs.aws.amazon.com/efs/latest/ug/mount-fs-auto-mount-onreboot.html#mount-fs-auto-mount-update-fstab

You need to configure three things:
1. Create EFS
2. Create EFS Security group
3. Add fstab command to write EFS ID and mount point to EKS worker node's userdata script so that every new EC2 created by ASG will auto-mount EFS from bootstrap script


# Step 1: Set `additional_userdata` in `worker_groups` in terraform.tfvars

In [composition/eks-demo-infra/ap-northeast-1/prod/terraform.tfvars](composition/eks-demo-infra/ap-northeast-1/prod/terraform.tfvars),
```sh
worker_groups = [
  {
    # this userdata will 1) block access to metadata to avoid pods from using node's IAM instance profile, 2) create /mnt/efs and auto-mount EFS to it using fstab, 3) install SSM agent.
    additional_userdata = "yum install -y iptables-services; iptables --insert FORWARD 1 --in-interface eni+ --destination 169.254.169.254/32 --jump DROP; iptables-save | tee /etc/sysconfig/iptables; systemctl enable --now iptables; sudo mkdir /mnt/efs; sudo mount -t nfs -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport fs-02940981.efs.us-east-1.amazonaws.com:/ /mnt/efs; echo 'fs-02940981.efs.us-east-1.amazonaws.com:/ /mnt/efs nfs defaults,vers=4.1 0 0' >> /etc/fstab; sudo yum install -y https://s3.us-east-1.amazonaws.com/amazon-ssm-us-east-1/latest/linux_amd64/amazon-ssm-agent.rpm; sudo systemctl enable amazon-ssm-agent; sudo systemctl start amazon-ssm-agent"
```

In [composition/eks-demo-infra/ap-northeast-1/prod/main.tf](composition/eks-demo-infra/ap-northeast-1/prod/main.tf),
```sh
########################################
# EKS
########################################
module "eks" {
  source = "../../../../infrastructure_modules/eks"

  ## EFS SG ##
  vpc_cidr_block = module.vpc.vpc_cidr_block

  ## EFS ## 
  efs_mount_target_subnet_ids = module.vpc.private_subnets
}
```



# Step 2: Create EFS module in infrastructure layer

In [infrastructure_modules/eks/main.tf](infrastructure_modules/eks/main.tf), create modules for EFS security group and EFS
```sh
module "efs_security_group" {
  source = "../../resource_modules/compute/security_group"

  name        = local.efs_security_group_name
  description = local.efs_security_group_description
  vpc_id      = var.vpc_id

  ingress_with_cidr_blocks                                 = local.efs_ingress_with_cidr_blocks
  computed_ingress_with_cidr_blocks                        = local.efs_computed_ingress_with_cidr_blocks
  number_of_computed_ingress_with_cidr_blocks              = local.efs_number_of_computed_ingress_with_cidr_blocks
  computed_ingress_with_source_security_group_id           = local.efs_computed_ingress_with_source_security_group_id
  number_of_computed_ingress_with_source_security_group_id = local.efs_computed_ingress_with_source_security_group_count

  egress_rules = ["all-all"]

  tags = local.efs_security_group_tags
}

module "efs" {
  source = "../../resource_modules/storage/efs"

  ## EFS FILE SYSTEM ## 
  encrypted = local.efs_encrypted
  tags      = local.efs_tags

  ## EFS MOUNT TARGET ## 
  mount_target_subnet_ids = var.efs_mount_target_subnet_ids
  security_group_ids      = [module.efs_security_group.this_security_group_id]
}
```

In [infrastructure_modules/eks/data.tf](infrastructure_modules/eks/data.tf),
```sh
  ## EFS SG ##
  efs_security_group_name                         = "scg-${var.region_tag[var.region]}-${var.env}-efs"
  efs_security_group_description                  = "Security group for EFS"
  efs_ingress_with_cidr_blocks_local              = []
  efs_ingress_with_cidr_blocks                    = []
  efs_number_of_computed_ingress_with_cidr_blocks = 1
  efs_computed_ingress_with_cidr_blocks = [
    {
      rule        = "nfs-tcp"
      cidr_blocks = var.vpc_cidr_block
      description = "Allow NFS 2049 from within the VPC"
    },
  ]
  efs_computed_ingress_with_source_security_group_count = 1
  efs_computed_ingress_with_source_security_group_id = [
    {
      rule                     = "nfs-tcp"
      source_security_group_id = module.eks_cluster.worker_security_group_id
      description              = "Allow NFS 2049 from EKS worker nodes"
    },
  ]
  efs_security_group_tags = merge(
    var.tags,
    map("Name", local.efs_security_group_name)
  )

  ## EFS ##
  efs_encrypted = true
  efs_tags      = merge(var.tags, map("Name", "efs-${var.region_tag[var.region]}-${var.app_name}-${var.env}"))
```

In [infrastructure_modules/eks/variables.tf](infrastructure_modules/eks/variables.tf), define input variables
```sh
## EFS SG ##
variable "vpc_cidr_block" {}

## EFS ##
variable efs_mount_target_subnet_ids {
  type = list
}
```


# Step 3: Create EFS resource in resource layer

In [resource_modules/storage/efs/main.tf](resource_modules/storage/efs/main.tf),
```sh
resource "aws_efs_file_system" "this" {
  creation_token = "terraform-efs"
  encrypted      = var.encrypted

  tags = var.tags

  lifecycle {
    prevent_destroy = "true"
  }

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }
}

resource "aws_efs_mount_target" "this" {
  count           = length(var.mount_target_subnet_ids)
  
  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = var.mount_target_subnet_ids[count.index]
  security_groups = var.security_group_ids
}
```

In [resource_modules/storage/efs/variables.tf](resource_modules/storage/efs/variables.tf)
```sh
## EFS FILE SYSTEM ## 
variable "encrypted" {}

variable "tags" {
  type = map
}

## EFS MOUNT TARGET ## 
variable "mount_target_subnet_ids" {
  type = list
}
variable "security_group_ids" {
  type = list
}
```


# Step 4: Terraform apply
```sh
terraform apply


# output
  # module.eks.module.efs.aws_efs_file_system.this will be created
  + resource "aws_efs_file_system" "this" {
      + arn              = (known after apply)
      + creation_token   = "terraform-efs"
      + dns_name         = (known after apply)
      + encrypted        = true
      + id               = (known after apply)
      + kms_key_id       = (known after apply)
      + performance_mode = (known after apply)
      + tags             = {
          + "Application"                                                       = "terraform-eks-demo-infra"
          + "Environment"                                                       = "prod"
          + "Name"                                                              = "efs-apne1-terraform-eks-demo-infra-prod"
          + "k8s.io/cluster-autoscaler/eks-apne1-prod-terraform-eks-demo-infra" = "true"
          + "kubernetes.io/cluster/eks-apne1-prod-terraform-eks-demo-infra"     = "shared"
        }
      + throughput_mode  = "bursting"

      + lifecycle_policy {
          + transition_to_ia = "AFTER_30_DAYS"
        }
    }

  # module.eks.module.efs.aws_efs_mount_target.this[0] will be created
  + resource "aws_efs_mount_target" "this" {
      + availability_zone_id   = (known after apply)
      + availability_zone_name = (known after apply)
      + dns_name               = (known after apply)
      + file_system_arn        = (known after apply)
      + file_system_id         = (known after apply)
      + id                     = (known after apply)
      + ip_address             = (known after apply)
      + mount_target_dns_name  = (known after apply)
      + network_interface_id   = (known after apply)
      + owner_id               = (known after apply)
      + security_groups        = (known after apply)
      + subnet_id              = "subnet-0fc42611fb1a46518"
    }

  # module.eks.module.efs.aws_efs_mount_target.this[1] will be created
  + resource "aws_efs_mount_target" "this" {
      + availability_zone_id   = (known after apply)
      + availability_zone_name = (known after apply)
      + dns_name               = (known after apply)
      + file_system_arn        = (known after apply)
      + file_system_id         = (known after apply)
      + id                     = (known after apply)
      + ip_address             = (known after apply)
      + mount_target_dns_name  = (known after apply)
      + network_interface_id   = (known after apply)
      + owner_id               = (known after apply)
      + security_groups        = (known after apply)
      + subnet_id              = "subnet-0cab9a62aa30058bf"
    }

  # module.eks.module.efs.aws_efs_mount_target.this[2] will be created
  + resource "aws_efs_mount_target" "this" {
      + availability_zone_id   = (known after apply)
      + availability_zone_name = (known after apply)
      + dns_name               = (known after apply)
      + file_system_arn        = (known after apply)
      + file_system_id         = (known after apply)
      + id                     = (known after apply)
      + ip_address             = (known after apply)
      + mount_target_dns_name  = (known after apply)
      + network_interface_id   = (known after apply)
      + owner_id               = (known after apply)
      + security_groups        = (known after apply)
      + subnet_id              = "subnet-072657231980c4efd"
    }

  # module.eks.module.efs_security_group.aws_security_group.this_name_prefix[0] will be created
  + resource "aws_security_group" "this_name_prefix" {
      + arn                    = (known after apply)
      + description            = "Security group for EFS"
      + egress                 = (known after apply)
      + id                     = (known after apply)
      + ingress                = (known after apply)
      + name                   = (known after apply)
      + name_prefix            = "scg-apne1-prod-efs-"
      + owner_id               = (known after apply)
      + revoke_rules_on_delete = false
      + tags                   = {
          + "Application"                                                       = "terraform-eks-demo-infra"
          + "Environment"                                                       = "prod"
          + "Name"                                                              = "scg-apne1-prod-efs"
          + "k8s.io/cluster-autoscaler/eks-apne1-prod-terraform-eks-demo-infra" = "true"
          + "kubernetes.io/cluster/eks-apne1-prod-terraform-eks-demo-infra"     = "shared"
        }
      + vpc_id                 = "vpc-0d19359dafc963090"
    }

  # module.eks.module.efs_security_group.aws_security_group_rule.computed_ingress_with_cidr_blocks[0] will be created
  + resource "aws_security_group_rule" "computed_ingress_with_cidr_blocks" {
      + cidr_blocks              = [
          + "10.1.0.0/16",
        ]
      + description              = "Allow NFS 2049 from within the VPC"
      + from_port                = 2049
      + id                       = (known after apply)
      + prefix_list_ids          = []
      + protocol                 = "tcp"
      + security_group_id        = (known after apply)
      + self                     = false
      + source_security_group_id = (known after apply)
      + to_port                  = 2049
      + type                     = "ingress"
    }

  # module.eks.module.efs_security_group.aws_security_group_rule.computed_ingress_with_source_security_group_id[0] will be created
  + resource "aws_security_group_rule" "computed_ingress_with_source_security_group_id" {
      + description              = "Allow NFS 2049 from EKS worker nodes"
      + from_port                = 2049
      + id                       = (known after apply)
      + prefix_list_ids          = []
      + protocol                 = "tcp"
      + security_group_id        = (known after apply)
      + self                     = false
      + source_security_group_id = "sg-0abfef384dcf2ec2a"
      + to_port                  = 2049
      + type                     = "ingress"
    }

  # module.eks.module.efs_security_group.aws_security_group_rule.egress_rules[0] will be created
  + resource "aws_security_group_rule" "egress_rules" {
      + cidr_blocks              = [
          + "0.0.0.0/0",
        ]
      + description              = "All protocols"
      + from_port                = -1
      + id                       = (known after apply)
      + ipv6_cidr_blocks         = [
          + "::/0",
        ]
      + prefix_list_ids          = []
      + protocol                 = "-1"
      + security_group_id        = (known after apply)
      + self                     = false
      + source_security_group_id = (known after apply)
      + to_port                  = -1
      + type                     = "egress"
    }

  # module.eks.module.eks_cluster.aws_autoscaling_group.workers[0] will be updated in-place
  ~ resource "aws_autoscaling_group" "workers" {
        id                        = "eks-apne1-prod-terraform-eks-demo-infra-worker-group-staging-120210330195944213900000017"
      ~ launch_configuration      = "eks-apne1-prod-terraform-eks-demo-infra-worker-group-staging-120210330200327706000000001" -> (known after apply)
        name                      = "eks-apne1-prod-terraform-eks-demo-infra-worker-group-staging-120210330195944213900000017"
        # (22 unchanged attributes hidden)

      + tag {
          + key                 = "kubernetes.io/cluster/eks-apne1-prod-terraform-eks-demo-infra"
          + propagate_at_launch = true
          + value               = "owned"
        }
        # (8 unchanged blocks hidden)
    }

  # module.eks.module.eks_cluster.aws_launch_configuration.workers[0] must be replaced
+/- resource "aws_launch_configuration" "workers" {
      ~ arn                              = "arn:aws:autoscaling:ap-northeast-1:266981300450:launchConfiguration:c655f6f2-5a58-4cd6-93ea-89b79c70a767:launchConfigurationName/eks-apne1-prod-terraform-eks-demo-infra-worker-group-staging-120210330200327706000000001" -> (known after apply)
      ~ id                               = "eks-apne1-prod-terraform-eks-demo-infra-worker-group-staging-120210330200327706000000001" -> (known after apply)
      ~ name                             = "eks-apne1-prod-terraform-eks-demo-infra-worker-group-staging-120210330200327706000000001" -> (known after apply)
      ~ user_data_base64                 = "IyEvYmluL2Jhc2ggLWUKCiMgQWxsb3cgdXNlciBzdXBwbGllZCBwcmUgdXNlcmRhdGEgY29kZQoKCiMgQm9vdHN0cmFwIGFuZCBqb2luIHRoZSBjbHVzdGVyCi9ldGMvZWtzL2Jvb3RzdHJhcC5zaCAtLWI2NC1jbHVzdGVyLWNhICdMUzB0TFMxQ1JVZEpUaUJEUlZKVVNVWkpRMEZVUlMwdExTMHRDazFKU1VONVJFTkRRV0pEWjBGM1NVSkJaMGxDUVVSQlRrSm5hM0ZvYTJsSE9YY3dRa0ZSYzBaQlJFRldUVkpOZDBWUldVUldVVkZFUlhkd2NtUlhTbXdLWTIwMWJHUkhWbnBOUWpSWVJGUkplRTFFVFhwTlJFVTFUbFJaZUU5R2IxaEVWRTE0VFVSTmVVOUVSVFZPVkZsNFQwWnZkMFpVUlZSTlFrVkhRVEZWUlFwQmVFMUxZVE5XYVZwWVNuVmFXRkpzWTNwRFEwRlRTWGRFVVZsS1MyOWFTV2gyWTA1QlVVVkNRbEZCUkdkblJWQkJSRU5EUVZGdlEyZG5SVUpCVDFVekNtSkZRbVppYTAxM2QxazBiVlZDUWtsbmFWWmlWRzUxVlUxSWQzQkpkVlZKUm5kRU4za3JTRkJOYzBwak5YTjNVRlpOY1hFeU4weDFNemczYjBrNVNYa0tRME5hV0V4WE1qZFJVSEZHVGs0eFRtZDJVMFZLU0RoTlUyTjBhbGRMWVd3eWNUQkhlRTlPTURJMWJuQXpSSHBUYlRsQk9FVk9UR0U1ZHk5WUt6SnJhQW92ZFdFemNVRlRPVEpDVlhKMWNVSmphVEl2ZDJvM2NrNVRRMWgyT0RVNU1WaE9NMHhQUW1sMk1FMWpkemRvVFM5UU1GQXJPRlpMYVcxSlpERmFPVmxVQ2xWa1UybFlSVWRoSzJkNk9UbENWbFpEYVhkeGExbGhjM2h0WlRBeVR6UktWblJJWmsxclJrdGpkaXQ0ZVc1alMwbEJjVEZKVTJwV0swTTFiMVZVTVZvS1pETnRaR2N2YkVwQldWRjJjR0p1ZWxacVpVZHFOVXN5Vm1OaGVVaHlhVXN2VVdGbll5dEJjbEl3VkdGaksydHpTWGQxY0ZaTlMyRk1OMGRUWlM4eFNRcG5iM0F2VGlzNVlqSkJXbTFHYWxrdloxSXdRMEYzUlVGQllVMXFUVU5GZDBSbldVUldVakJRUVZGSUwwSkJVVVJCWjB0clRVRTRSMEV4VldSRmQwVkNDaTkzVVVaTlFVMUNRV1k0ZDBSUldVcExiMXBKYUhaalRrRlJSVXhDVVVGRVoyZEZRa0ZEUmxSaVZHNUxWVzh3UlhCeFNFY3ZObVU1TTNKbWJHWmFZelFLU2xsVmVFSXJNMDE0ZW5FdlluQnFSbFJWUWpGeFQyVXpVMjFJVmpSbk9VRlVjMDVWV1ZoTWVFMUhSelJNYVRBMVpHWkxiMkUzWlZsRlNIZHFWbk5WVHdwb1ltRk5VQzlHTVd4TE0xUlNRMmROV0drMGJWRnliM0J4WVRWTlMwczRiRGt5ZGxZelNWVmtVVVpTYVRack0zSndiRlJHZDNRd2NXRnlSVTFJVWxaM0NuWmpaMWhOU1U5VWNXMVZSRGxIWW10TFoyTkxaRzVJVTBoR05FTkpVbWRZT1VaQ1lrNHdVa2hRZVhSWE1IZFRWa0pTVERsclVWaFlVa1ZvT1hWQmNUVUtXR3N3UzNWaE9UQXlUVUp2V2pZd1VFZGlhbEZsV0RGcGNVNTJPVkZKY0RORlNuRnVLMlp5TlVFNWVrSjBNR05aWVRBemJIbEZlSFZyTkhFM2FWRmxZZ3B1YzJWWGNFaExjRTlJVURoblNrMUJXWGhKTldVeGVEaHlZakZzV1RWdFExWnNaR1JNVDNJclEzSkphRzA0U25Vdk5EQkNaVTVETVVGNVJUMEtMUzB0TFMxRlRrUWdRMFZTVkVsR1NVTkJWRVV0TFMwdExRbz0nIC0tYXBpc2VydmVyLWVuZHBvaW50ICdodHRwczovLzZDNjhDMzNDRDcwRjEyODE1Qzk5MjI5MkJBMDI0QkJCLnNrMS5hcC1ub3J0aGVhc3QtMS5la3MuYW1hem9uYXdzLmNvbScgIC0ta3ViZWxldC1leHRyYS1hcmdzICItLW5vZGUtbGFiZWxzPWVudj1zdGFnaW5nLHVubWFuYWdlZC1ub2RlPXRydWUgLS1yZWdpc3Rlci13aXRoLXRhaW50cz1zdGFnaW5nLW9ubHk9dHJ1ZTpQcmVmZXJOb1NjaGVkdWxlIiAnZWtzLWFwbmUxLXByb2QtdGVycmFmb3JtLWVrcy1kZW1vLWluZnJhJwoKIyBBbGxvdyB1c2VyIHN1cHBsaWVkIHVzZXJkYXRhIGNvZGUK" -> "IyEvYmluL2Jhc2ggLWUKCiMgQWxsb3cgdXNlciBzdXBwbGllZCBwcmUgdXNlcmRhdGEgY29kZQoKCiMgQm9vdHN0cmFwIGFuZCBqb2luIHRoZSBjbHVzdGVyCi9ldGMvZWtzL2Jvb3RzdHJhcC5zaCAtLWI2NC1jbHVzdGVyLWNhICdMUzB0TFMxQ1JVZEpUaUJEUlZKVVNVWkpRMEZVUlMwdExTMHRDazFKU1VONVJFTkRRV0pEWjBGM1NVSkJaMGxDUVVSQlRrSm5hM0ZvYTJsSE9YY3dRa0ZSYzBaQlJFRldUVkpOZDBWUldVUldVVkZFUlhkd2NtUlhTbXdLWTIwMWJHUkhWbnBOUWpSWVJGUkplRTFFVFhwTlJFVTFUbFJaZUU5R2IxaEVWRTE0VFVSTmVVOUVSVFZPVkZsNFQwWnZkMFpVUlZSTlFrVkhRVEZWUlFwQmVFMUxZVE5XYVZwWVNuVmFXRkpzWTNwRFEwRlRTWGRFVVZsS1MyOWFTV2gyWTA1QlVVVkNRbEZCUkdkblJWQkJSRU5EUVZGdlEyZG5SVUpCVDFVekNtSkZRbVppYTAxM2QxazBiVlZDUWtsbmFWWmlWRzUxVlUxSWQzQkpkVlZKUm5kRU4za3JTRkJOYzBwak5YTjNVRlpOY1hFeU4weDFNemczYjBrNVNYa0tRME5hV0V4WE1qZFJVSEZHVGs0eFRtZDJVMFZLU0RoTlUyTjBhbGRMWVd3eWNUQkhlRTlPTURJMWJuQXpSSHBUYlRsQk9FVk9UR0U1ZHk5WUt6SnJhQW92ZFdFemNVRlRPVEpDVlhKMWNVSmphVEl2ZDJvM2NrNVRRMWgyT0RVNU1WaE9NMHhQUW1sMk1FMWpkemRvVFM5UU1GQXJPRlpMYVcxSlpERmFPVmxVQ2xWa1UybFlSVWRoSzJkNk9UbENWbFpEYVhkeGExbGhjM2h0WlRBeVR6UktWblJJWmsxclJrdGpkaXQ0ZVc1alMwbEJjVEZKVTJwV0swTTFiMVZVTVZvS1pETnRaR2N2YkVwQldWRjJjR0p1ZWxacVpVZHFOVXN5Vm1OaGVVaHlhVXN2VVdGbll5dEJjbEl3VkdGaksydHpTWGQxY0ZaTlMyRk1OMGRUWlM4eFNRcG5iM0F2VGlzNVlqSkJXbTFHYWxrdloxSXdRMEYzUlVGQllVMXFUVU5GZDBSbldVUldVakJRUVZGSUwwSkJVVVJCWjB0clRVRTRSMEV4VldSRmQwVkNDaTkzVVVaTlFVMUNRV1k0ZDBSUldVcExiMXBKYUhaalRrRlJSVXhDVVVGRVoyZEZRa0ZEUmxSaVZHNUxWVzh3UlhCeFNFY3ZObVU1TTNKbWJHWmFZelFLU2xsVmVFSXJNMDE0ZW5FdlluQnFSbFJWUWpGeFQyVXpVMjFJVmpSbk9VRlVjMDVWV1ZoTWVFMUhSelJNYVRBMVpHWkxiMkUzWlZsRlNIZHFWbk5WVHdwb1ltRk5VQzlHTVd4TE0xUlNRMmROV0drMGJWRnliM0J4WVRWTlMwczRiRGt5ZGxZelNWVmtVVVpTYVRack0zSndiRlJHZDNRd2NXRnlSVTFJVWxaM0NuWmpaMWhOU1U5VWNXMVZSRGxIWW10TFoyTkxaRzVJVTBoR05FTkpVbWRZT1VaQ1lrNHdVa2hRZVhSWE1IZFRWa0pTVERsclVWaFlVa1ZvT1hWQmNUVUtXR3N3UzNWaE9UQXlUVUp2V2pZd1VFZGlhbEZsV0RGcGNVNTJPVkZKY0RORlNuRnVLMlp5TlVFNWVrSjBNR05aWVRBemJIbEZlSFZyTkhFM2FWRmxZZ3B1YzJWWGNFaExjRTlJVURoblNrMUJXWGhKTldVeGVEaHlZakZzV1RWdFExWnNaR1JNVDNJclEzSkphRzA0U25Vdk5EQkNaVTVETVVGNVJUMEtMUzB0TFMxRlRrUWdRMFZTVkVsR1NVTkJWRVV0TFMwdExRbz0nIC0tYXBpc2VydmVyLWVuZHBvaW50ICdodHRwczovLzZDNjhDMzNDRDcwRjEyODE1Qzk5MjI5MkJBMDI0QkJCLnNrMS5hcC1ub3J0aGVhc3QtMS5la3MuYW1hem9uYXdzLmNvbScgIC0ta3ViZWxldC1leHRyYS1hcmdzICItLW5vZGUtbGFiZWxzPWVudj1zdGFnaW5nLHVubWFuYWdlZC1ub2RlPXRydWUgLS1yZWdpc3Rlci13aXRoLXRhaW50cz1zdGFnaW5nLW9ubHk9dHJ1ZTpQcmVmZXJOb1NjaGVkdWxlIiAnZWtzLWFwbmUxLXByb2QtdGVycmFmb3JtLWVrcy1kZW1vLWluZnJhJwoKIyBBbGxvdyB1c2VyIHN1cHBsaWVkIHVzZXJkYXRhIGNvZGUKeXVtIGluc3RhbGwgLXkgaXB0YWJsZXMtc2VydmljZXM7IGlwdGFibGVzIC0taW5zZXJ0IEZPUldBUkQgMSAtLWluLWludGVyZmFjZSBlbmkrIC0tZGVzdGluYXRpb24gMTY5LjI1NC4xNjkuMjU0LzMyIC0tanVtcCBEUk9QOyBpcHRhYmxlcy1zYXZlIHwgdGVlIC9ldGMvc3lzY29uZmlnL2lwdGFibGVzOyBzeXN0ZW1jdGwgZW5hYmxlIC0tbm93IGlwdGFibGVzOyBzdWRvIG1rZGlyIC9tbnQvZWZzOyBzdWRvIG1vdW50IC10IG5mcyAtbyBuZnN2ZXJzPTQuMSxyc2l6ZT0xMDQ4NTc2LHdzaXplPTEwNDg1NzYsaGFyZCx0aW1lbz02MDAscmV0cmFucz0yLG5vcmVzdnBvcnQgZnMtZGFzYWRhc2QuZWZzLnVzLWVhc3QtMS5hbWF6b25hd3MuY29tOi8gL21udC9lZnM7IGVjaG8gJ2ZzLTAyOTQwOTgxLmVmcy51cy1lYXN0LTEuYW1hem9uYXdzLmNvbTovIC9tbnQvZWZzIG5mcyBkZWZhdWx0cyx2ZXJzPTQuMSAwIDAnID4+IC9ldGMvZnN0YWI7IHN1ZG8geXVtIGluc3RhbGwgLXkgaHR0cHM6Ly9zMy51cy1lYXN0LTEuYW1hem9uYXdzLmNvbS9hbWF6b24tc3NtLXVzLWVhc3QtMS9sYXRlc3QvbGludXhfYW1kNjQvYW1hem9uLXNzbS1hZ2VudC5ycG07IHN1ZG8gc3lzdGVtY3RsIGVuYWJsZSBhbWF6b24tc3NtLWFnZW50OyBzdWRvIHN5c3RlbWN0bCBzdGFydCBhbWF6b24tc3NtLWFnZW50" # forces replacement
      - vpc_classic_link_security_groups = [] -> null
        # (9 unchanged attributes hidden)

      + ebs_block_device {
          + delete_on_termination = (known after apply)
          + device_name           = (known after apply)
          + encrypted             = (known after apply)
          + iops                  = (known after apply)
          + no_device             = (known after apply)
          + snapshot_id           = (known after apply)
          + volume_size           = (known after apply)
          + volume_type           = (known after apply)
        }

      + metadata_options {
          + http_endpoint               = (known after apply)
          + http_put_response_hop_limit = (known after apply)
          + http_tokens                 = (known after apply)
        }

        # (1 unchanged block hidden)
    }

  # module.eks.module.eks_cluster.local_file.kubeconfig[0] will be created
  + resource "local_file" "kubeconfig" {
      + content              = <<-EOT
            apiVersion: v1
            preferences: {}
            kind: Config
            
            clusters:
            - cluster:
                server: https://6C68C33CD70F12815C992292BA024BBB.sk1.ap-northeast-1.eks.amazonaws.com
                certificate-authority-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUN5RENDQWJDZ0F3SUJBZ0lCQURBTkJna3Foa2lHOXcwQkFRc0ZBREFWTVJNd0VRWURWUVFERXdwcmRXSmwKY201bGRHVnpNQjRYRFRJeE1ETXpNREU1TlRZeE9Gb1hEVE14TURNeU9ERTVOVFl4T0Zvd0ZURVRNQkVHQTFVRQpBeE1LYTNWaVpYSnVaWFJsY3pDQ0FTSXdEUVlKS29aSWh2Y05BUUVCQlFBRGdnRVBBRENDQVFvQ2dnRUJBT1UzCmJFQmZia013d1k0bVVCQklnaVZiVG51VU1Id3BJdVVJRndEN3krSFBNc0pjNXN3UFZNcXEyN0x1Mzg3b0k5SXkKQ0NaWExXMjdRUHFGTk4xTmd2U0VKSDhNU2N0aldLYWwycTBHeE9OMDI1bnAzRHpTbTlBOEVOTGE5dy9YKzJraAovdWEzcUFTOTJCVXJ1cUJjaTIvd2o3ck5TQ1h2ODU5MVhOM0xPQml2ME1jdzdoTS9QMFArOFZLaW1JZDFaOVlUClVkU2lYRUdhK2d6OTlCVlZDaXdxa1lhc3htZTAyTzRKVnRIZk1rRktjdit4eW5jS0lBcTFJU2pWK0M1b1VUMVoKZDNtZGcvbEpBWVF2cGJuelZqZUdqNUsyVmNheUhyaUsvUWFnYytBclIwVGFjK2tzSXd1cFZNS2FMN0dTZS8xSQpnb3AvTis5YjJBWm1GalkvZ1IwQ0F3RUFBYU1qTUNFd0RnWURWUjBQQVFIL0JBUURBZ0trTUE4R0ExVWRFd0VCCi93UUZNQU1CQWY4d0RRWUpLb1pJaHZjTkFRRUxCUUFEZ2dFQkFDRlRiVG5LVW8wRXBxSEcvNmU5M3JmbGZaYzQKSllVeEIrM014enEvYnBqRlRVQjFxT2UzU21IVjRnOUFUc05VWVhMeE1HRzRMaTA1ZGZLb2E3ZVlFSHdqVnNVTwpoYmFNUC9GMWxLM1RSQ2dNWGk0bVFyb3BxYTVNS0s4bDkydlYzSVVkUUZSaTZrM3JwbFRGd3QwcWFyRU1IUlZ3CnZjZ1hNSU9UcW1VRDlHYmtLZ2NLZG5IU0hGNENJUmdYOUZCYk4wUkhQeXRXMHdTVkJSTDlrUVhYUkVoOXVBcTUKWGswS3VhOTAyTUJvWjYwUEdialFlWDFpcU52OVFJcDNFSnFuK2ZyNUE5ekJ0MGNZYTAzbHlFeHVrNHE3aVFlYgpuc2VXcEhLcE9IUDhnSk1BWXhJNWUxeDhyYjFsWTVtQ1ZsZGRMT3IrQ3JJaG04SnUvNDBCZU5DMUF5RT0KLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo=
              name: eks-apne1-prod-terraform-eks-demo-infra
            
            contexts:
            - context:
                cluster: eks-apne1-prod-terraform-eks-demo-infra
                user: eks-apne1-prod-terraform-eks-demo-infra
              name: eks-apne1-prod-terraform-eks-demo-infra
            
            current-context: eks-apne1-prod-terraform-eks-demo-infra
            
            users:
            - name: eks-apne1-prod-terraform-eks-demo-infra
              user:
                exec:
                  apiVersion: client.authentication.k8s.io/v1alpha1
                  command: aws-iam-authenticator
                  args:
                    - "token"
                    - "-i"
                    - "eks-apne1-prod-terraform-eks-demo-infra"
        EOT
      + directory_permission = "0755"
      + file_permission      = "0644"
      + filename             = "./kubeconfig_eks-apne1-prod-terraform-eks-demo-infra"
      + id                   = (known after apply)
    }

  # module.eks.module.eks_cluster.random_pet.workers[0] must be replaced
+/- resource "random_pet" "workers" {
      ~ id        = "skilled-goshawk" -> (known after apply)
      ~ keepers   = {
          - "lc_name" = "eks-apne1-prod-terraform-eks-demo-infra-worker-group-staging-120210330200327706000000001"
        } -> (known after apply) # forces replacement
        # (2 unchanged attributes hidden)
    }

Plan: 11 to add, 1 to change, 2 to destroy.
```


# Step 5: SSH into EKS worker node and check if EFS is mounted at /mnt/efs

## 5.1 Create Bastion EC2 in public subnet

## 5.2 Add Ingress rule for port 22 from Bastion SG ID to EKS worker node SG

## 5.3 SSH into Bastion in public subnet, then EKS worker node in private subnet

```sh
# copy bastion private SSH key to ~/.ssh/aws-demo
mv ../../../../../../../Downloads/esk-demo-bastion.pem ~/.ssh/aws-demo/eks-demo-bastion.pem

eval $(ssh-agent)
sudo chmod 400 ~/.ssh/aws-demo/eks-demo-bastion.pem
ssh-add -k ~/.ssh/aws-demo/eks-demo-bastion.pem

# copy EKS worker node's private SSH key to Bastion (Not recommended for production!!)
# given that you already created ssh key by running "ssh-keygen" to ~/.ssh/aws-demo/eks-demo-workers in ch5
scp ~/.ssh/aws-demo/eks-demo-workers.pem ec2-user@13.231.8.75:~/.ssh/eks-demo-workers.pem

# ssh into Bastion
ssh -A ec2-user@13.231.8.75
ls ~/.ssh

# ssh into EKS worker node
ssh -i ~/.ssh/eks-demo-workers.pem ec2-user@10.1.102.76

# check mounted volume
df -h

# create a file in EFS
sudo su
touch /mnt/efs/hello.txt
echo "hello world" >> /mnt/efs/hello.txt
cat /mnt/efs/hello.txt

# terminate EC2 and check /mnt/efs/hello.txt persiste in EFS
```


# Clean up

```sh
# destroy EKS, VPC, EFS, etc
terraform destroy

# destroy Terraform remote backend S3 bucket and DynamoDB
cd ../../../terraform-remote-backend/ap-northeast-1/prod
terraform init
terraform destroy
```