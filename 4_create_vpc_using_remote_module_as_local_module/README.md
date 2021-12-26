# Create VPC with 3-layered subnets

![alt text](../imgs/3_layered_vpc.png "")

Project architecture:
```sh
.
├── README.md
├── composition
│   ├── eks-demo-infra # <--- Step 3: Create Composition layer and define all the required inputs to Infrastructure module's VPC main.tf
│   │   └── ap-northeast-1
│   │       └── prod
│   │           ├── backend.config
│   │           ├── data.tf
│   │           ├── main.tf # <----- this is the entry point for VPC
│   │           ├── outputs.tf
│   │           ├── providers.tf
│   │           ├── terraform.tfenvs
│   │           └── variables.tf
│   └── terraform-remote-backend 
│       └── ap-northeast-1 
│           └── prod      
│               ├── data.tf
│               ├── main.tf 
│               ├── outputs.tf
│               ├── providers.tf
│               ├── terraform.tfstate
│               ├── terraform.tfstate.backup
│               ├── terraform.tfvars
│               └── variables.tf
├── infrastructure_modules 
│   ├── terraform_remote_backend
│   │   ├── data.tf
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   └── variables.tf
│   └── vpc # <---- Step 2: Create Infrastructure Modules for VPC and Consume Resource Modules
│       ├── data.tf
│       ├── main.tf
│       ├── outputs.tf
│       ├── provider.tf
│       ├── variables.tf
│       └── versions.tf
└── resource_modules 
    ├── compute
    │   └── security_group  # <----- Step 1: Replicate remote TF modules in local Resource Modules
    │       ├── main.tf
    │       ├── outputs.tf
    │       ├── rules.tf
    │       └── variables.tf
    ├── database
    │   └── dynamodb
    │       ├── main.tf
    │       ├── outputs.tf
    │       └── variables.tf
    ├── identity
    │   └── kms_key
    │       ├── main.tf
    │       ├── outputs.tf
    │       └── variables.tf 
    ├── network
    │   └── vpc # <----- Step 1: Replicate remote TF modules in local Resource Modules
    │       ├── main.tf
    │       ├── outputs.tf
    │       └── variables.tf
    └── storage
        └── s3   
            ├── main.tf      
            ├── outputs.tf
            └── variables.tf
```

# Step 1: Replicate Remote TF modules for VPC and SG in local Resource Modules

## VPC
Copy paste all the .tf at the root of this repo https://github.com/terraform-aws-modules/terraform-aws-vpc to `resource_modules/network/vpc`.

## Security group
Copy paste all the .tf at the root of this repo https://github.com/terraform-aws-modules/terraform-aws-security-group to `resource_modules/compute/security-group`.


# Step 2: Create Infrastructure Modules for VPC and Consume Resource Modules

Using [AWS Terraform Remote Module's examples](https://github.com/terraform-aws-modules/terraform-aws-vpc/blob/master/examples/complete-vpc/main.tf), create VPC infra module's main.tf.

In [infrastructure_modules/vpc/main.tf](infrastructure_modules/vpc/main.tf), module `vpc` will act as a __facade__ to many sub-components such as VPC, IGW, NAT GW, subnets, route table, routes, etc.

```sh
module "vpc" {
  source = "../../resource_modules/network/vpc"

  name = var.name
  cidr = var.cidr

  azs              = var.azs
  private_subnets  = var.private_subnets
  public_subnets   = var.public_subnets
  database_subnets = var.database_subnets

  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway

  tags                 = var.tags
  public_subnet_tags   = local.public_subnet_tags
  private_subnet_tags  = local.private_subnet_tags
  database_subnet_tags = local.database_subnet_tags
}

# allow ingress for port 80 & 443 from anywhere (i.e. source CIDR 0.0.0.0/0)
module "public_security_group" {
  source = "../../resource_modules/compute/security_group"

  name        = local.public_security_group_name
  description = local.public_security_group_description
  vpc_id      = module.vpc.vpc_id

  ingress_rules            = ["http-80-tcp", "https-443-tcp"] # ref: https://github.com/terraform-aws-modules/terraform-aws-security-group/blob/master/examples/complete/main.tf#L44
  ingress_cidr_blocks      = ["0.0.0.0/0"]
  ingress_with_cidr_blocks = var.public_ingress_with_cidr_blocks

  # allow all egress
  egress_rules = ["all-all"]
  tags         = local.public_security_group_tags
}

# allow ingress only from public SG for port 80, 443, and 22
module "private_security_group" {
  source = "../../resource_modules/compute/security_group"

  name        = local.private_security_group_name
  description = local.private_security_group_description
  vpc_id      = module.vpc.vpc_id

  # define ingress source as computed security group IDs, not CIDR block
  # ref: https://github.com/terraform-aws-modules/terraform-aws-security-group/blob/master/examples/complete/main.tf#L150
  computed_ingress_with_source_security_group_id = [
    {
      rule                     = "http-80-tcp"
      source_security_group_id = module.public_security_group.this_security_group_id
      description              = "Port 80 from public SG rule"
    },
    {
      rule                     = "https-443-tcp"
      source_security_group_id = module.public_security_group.this_security_group_id
      description              = "Port 443 from public SG rule"
    },
    # bastion EC2 not created yet 
    # {
    #   rule                     = "ssh-tcp"
    #   source_security_group_id = var.bastion_sg_id
    #   description              = "SSH from bastion SG rule"
    # },
  ]
  number_of_computed_ingress_with_source_security_group_id = 2

  # allow ingress from within (i.e. connecting from EC2 to other EC2 associated with the same private SG)
  ingress_with_self = [
    {
      rule        = "all-all"
      description = "Self"
    },
  ]

  # allow all egress
  egress_rules                                             = ["all-all"]
  tags                                                     = local.private_security_group_tags
}

# allow ingress from private SG for port 27017-19 for mongoDB and port 3306 for MySQL
module "database_security_group" {
  source = "../../resource_modules/compute/security_group"

  name        = local.db_security_group_name
  description = local.db_security_group_description
  vpc_id      = module.vpc.vpc_id

  # combine list of SG rules from EKS worker SG and private SG
  computed_ingress_with_source_security_group_id           = concat(local.db_security_group_computed_ingress_with_source_security_group_id, var.databse_computed_ingress_with_eks_worker_source_security_group_ids)
  number_of_computed_ingress_with_source_security_group_id = var.create_eks ? 7 : 4

  # Open for self (rule or from_port+to_port+protocol+description)
  ingress_with_self = [
    {
      rule        = "all-all"
      description = "Self"
    },
  ]

  # allow all egress
  egress_rules = ["all-all"]
  tags         = local.db_security_group_tags
}
```



# Step 3: Create Composition layer and define all the required inputs to Infrastructure VPC module's main.tf

In [composition/eks-demo-infra/ap-northeast-1/prod/main.tf](composition/eks-demo-infra/ap-northeast-1/prod/main.tf), a single module called `vpc` is defined.

This is kind of thought as main class's main(), which just calls `infrastructure_modules/vpc` which creates VPC related resources (VPC, IGW, NAT GW, RT, Subnets, SG, etc) internally.

```sh
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
```


Finally supply input variable values in [composition/eks-demo-infra/ap-northeast-1/prod/terraform.tfvars](composition/eks-demo-infra/ap-northeast-1/prod/terraform.tfvars):

```sh
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

create_eks = false
```

Then run terraform commands
```sh
cd composition/eks-demo-infra/ap-northeast-1/prod

# will use remote backend
terraform init -backend-config=backend.config

# usual steps
terraform plan
terraform apply

# Successful output
Apply complete! Resources: 43 added, 0 changed, 0 destroyed.
Releasing state lock. This may take a few moments...

Outputs:

database_network_acl_id = ""
database_route_table_ids = tolist([
  "rtb-05cd8f1ee199e829d",
])
database_security_group_id = "sg-0cfa939b62d328fdd"
database_security_group_name = "scg-apne1-prod-database-20210216172630941200000002"
database_security_group_owner_id = "xxxxxxx"
database_security_group_vpc_id = "vpc-07e4383b75c37b1e0"
database_subnet_arns = [
  "arn:aws:ec2:ap-northeast-1:xxxxxxx:subnet/subnet-0235daeeafb2eb86e",
  "arn:aws:ec2:ap-northeast-1:xxxxxxx:subnet/subnet-0d4fe98223c85a7d5",
  "arn:aws:ec2:ap-northeast-1:xxxxxxx:subnet/subnet-0d1a9f4f51a7bcf14",
]
database_subnet_group = "terraform-eks-demo-infra"
database_subnets = [
  "subnet-0235daeeafb2eb86e",
  "subnet-0d4fe98223c85a7d5",
  "subnet-0d1a9f4f51a7bcf14",
]
database_subnets_cidr_blocks = [
  "10.1.105.0/24",
  "10.1.106.0/24",
  "10.1.107.0/24",
]
igw_id = "igw-0c731c8c529ac6291"
nat_ids = [
  "eipalloc-0a19db1dfc7f28e10",
]
nat_public_ips = tolist([
  "13.115.36.4",
])
natgw_ids = [
  "nat-04c7aac5dd187894e",
]
private_network_acl_id = ""
private_route_table_ids = [
  "rtb-05cd8f1ee199e829d",
]
private_security_group_id = "sg-081c4c5ed67883b98"
private_security_group_name = "scg-apne1-prod-private-20210216172630729700000001"
private_security_group_owner_id = "xxxxxxx"
private_security_group_vpc_id = "vpc-07e4383b75c37b1e0"
private_subnets = [
  "subnet-059466b92e5120afa",
  "subnet-088cbeb573a80e947",
  "subnet-016792c80e93d31bf",
]
private_subnets_cidr_blocks = [
  "10.1.101.0/24",
  "10.1.102.0/24",
  "10.1.103.0/24",
]
public_network_acl_id = ""
public_route_table_ids = [
  "rtb-0867c95134399ef38",
]
public_security_group_id = "sg-0771d52c3ba5d9642"
public_security_group_name = "scg-apne1-prod-public-20210216172630960800000003"
public_security_group_owner_id = "xxxxxxx"
public_security_group_vpc_id = "vpc-07e4383b75c37b1e0"
public_subnets = [
  "subnet-0f5d3c1c7f306792b",
  "subnet-090c4f0f00583036b",
  "subnet-0a82b1828528f6aa7",
]
public_subnets_cidr_blocks = [
  "10.1.1.0/24",
  "10.1.2.0/24",
  "10.1.3.0/24",
]
vpc_cidr_block = "10.1.0.0/16"
vpc_enable_dns_hostnames = true
vpc_enable_dns_support = true
vpc_id = "vpc-07e4383b75c37b1e0"
vpc_instance_tenancy = "default"
vpc_main_route_table_id = "rtb-03701d293fea25d41"
vpc_secondary_cidr_blocks = []
```
