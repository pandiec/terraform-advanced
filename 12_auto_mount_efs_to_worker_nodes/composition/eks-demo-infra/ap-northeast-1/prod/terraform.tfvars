########################################
# Environment setting
########################################
region = "ap-northeast-1"
role_name    = "Admin"
profile_name = "aws-demo"
env = "prod"
application_name = "terraform-eks-demo-infra"
app_name = "terraform-eks-demo-infra"

########################################
# VPC
########################################
cidr                  = "10.1.0.0/16" 
azs                   = ["ap-northeast-1a", "ap-northeast-1c", "ap-northeast-1d"]
public_subnets        = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"] # 256 IPs per subnet
private_subnets       = ["10.1.101.0/24", "10.1.102.0/24", "10.1.103.0/24"]
database_subnets      = ["10.1.105.0/24", "10.1.106.0/24", "10.1.107.0/24"]
enable_dns_hostnames  = "true"
enable_dns_support    = "true"
enable_nat_gateway    = "true" # need internet connection for worker nodes in private subnets to be able to join the cluster 
single_nat_gateway    = "true"


## Public Security Group ##
public_ingress_with_cidr_blocks = []

create_eks = true

########################################
# EKS
########################################
cluster_version = 1.18

# if set to true, AWS IAM Authenticator will use IAM role specified in "role_name" to authenticate to a cluster
authenticate_using_role = true

# if set to true, AWS IAM Authenticator will use AWS Profile name specified in profile_name to authenticate to a cluster instead of access key and secret access key
authenticate_using_aws_profile = false

# add other IAM users who can access a K8s cluster (by default, the IAM user who created a cluster is given access already)
map_users = []

# WARNING: mixing managed and unmanaged node groups will render unmanaged nodes to be unable to connect to internet & join the cluster when restarting.
# how many groups of K8s worker nodes you want? Specify at least one group of worker node
# gotcha: managed node group doesn't support 1) propagating taint to K8s nodes and 2) custom userdata. Ref: https://eksctl.io/usage/eks-managed-nodes/#feature-parity-with-unmanaged-nodegroups
node_groups = {}

# note (only for unmanaged node group)
# gotcha: need to use kubelet_extra_args to propagate taints/labels to K8s node, because ASG tags not being propagated to k8s node objects.
# ref: https://github.com/kubernetes/autoscaler/issues/1793#issuecomment-517417680
# ref: https://github.com/kubernetes/autoscaler/issues/2434#issuecomment-576479025
worker_groups = [
  {
    name                 = "worker-group-staging-1"
    instance_type        = "m3.medium" # since we are using AWS-VPC-CNI, allocatable pod IPs are defined by instance size: https://docs.google.com/spreadsheets/d/1MCdsmN7fWbebscGizcK6dAaPGS-8T_dYxWp0IdwkMKI/edit#gid=1549051942, https://github.com/awslabs/amazon-eks-ami/blob/master/files/eni-max-pods.txt
    asg_max_size         = 2
    asg_min_size         = 1
    asg_desired_capacity = 1 # this will be ignored if cluster autoscaler is enabled: asg_desired_capacity: https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/docs/autoscaling.md#notes
    # this userdata will 1) block access to instance metadata to avoid pods from using node's IAM instance profile (ref: https://docs.aws.amazon.com/eks/latest/userguide/best-practices-security.html), 2) create /mnt/efs and auto-mount EFS to it using fstab, 3) install SSM agent. Note: userdata script doesn't resolve shell variable defined within
    # ref: https://docs.aws.amazon.com/eks/latest/userguide/restrict-ec2-credential-access.html
    # UPDATE: Datadog agent needs to ping the EC2 metadata endpoint to retrieve the instance id and resolve duplicated hosts to be a single host, and currently no altenative solution so need to allow access to instance metadata unfortunately otherwise infra hosts get counted twice
    additional_userdata = "yum install -y iptables-services; iptables --insert FORWARD 1 --in-interface eni+ --destination 169.254.169.254/32 --jump DROP; iptables-save | tee /etc/sysconfig/iptables; systemctl enable --now iptables; sudo mkdir /mnt/efs; sudo mount -t nfs -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport fs-01e24d21.efs.ap-northeast-1.amazonaws.com:/ /mnt/efs; echo 'fs-01e24d21.efs.ap-northeast-1.amazonaws.com:/ /mnt/efs nfs defaults,vers=4.1 0 0' >> /etc/fstab; sudo yum install -y https://s3.us-east-1.amazonaws.com/amazon-ssm-us-east-1/latest/linux_amd64/amazon-ssm-agent.rpm; sudo systemctl enable amazon-ssm-agent; sudo systemctl start amazon-ssm-agent"
    kubelet_extra_args  = "--node-labels=env=staging,unmanaged-node=true --register-with-taints=staging-only=true:PreferNoSchedule" # for unmanaged nodes, taints and labels work only with extra-arg, not ASG tags. Ref: https://aws.amazon.com/blogs/opensource/improvements-eks-worker-node-provisioning/
    root_encrypted      = true
    tags = [
      {
        "key"                 = "unmanaged-node"
        "propagate_at_launch" = "true"
        "value"               = "true"
      },
      {
        "key"                 = "k8s.io/cluster-autoscaler/enabled"
        "propagate_at_launch" = "true"
        "value"               = "true"
      },
    ]
  },
]


## IRSA (IAM role for service account) ##
enable_irsa                                            = true

test_irsa_service_account_namespace                = "default"
test_irsa_service_account_name                     = "test-irsa"

cluster_autoscaler_service_account_namespace           = "kube-system"
cluster_autoscaler_service_account_name                = "cluster-autoscaler-aws-cluster-autoscaler"

enabled_cluster_log_types     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
cluster_log_retention_in_days = 90 # default 90 days