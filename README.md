# Advanced Terraform for AWS EKS and VPC (v0.14 & v1.9)


# 5 Reasons why you should take this course:

## 1. Instructed by a cloud DevOps engineer (with CKA and certified AWS DevOps pro) working at US company in SF

I have been pretty handson with Terraform and AWS EKS with 7+ industry experience in both North America and Europe.

Here is a subset of AWS architecture that I have deployed using Terraform
![alt text](imgs/aws_architecture_diagram.png "")



## 2. Practical, Scalable, and Extensible Terraform Design Pattern that abstracts and modularzises resources well

It is not enough to take some basic Terraform courses to build production-ready cloud infrastructures.

Most courses don't teach you __how to make Terraform code scalable__, actually they don't even mention it.

The standard software design principles still apply to Terraform and I will cover one of those in this course (i.e. __Facade pattern__), so that you can build clean, scalable, managable, and extensible terraform code.

![alt text](imgs/three_layered_modules.png "")

Contrary to what you often see on the internet and demo code, the below code architecture can __barely scale__ for production usage:
```sh
.
── us-east-1 
│   ├── prod
│   │   ├── backend.config
│   │   ├── main.tf  <------ # main entrypoint
├── modules # <------ modules contain reusable code
│   ├── compute
│   │   ├── ec2
│   │   ├── ec2_key_pair
│   │   ├── security_group
│   │   └── ssm
│   ├── network
│   │   ├── route53
│   │   │   ├── hosted_zone
│   │   │   └── record
│   │   └── vpc
│   └── storage
│       ├── dynamodb
│       ├── efs
│       └── s3
```

We will cover more advanced and scalable design in chapter in `2.2_three_layered_modules/`:
```sh
$ tree 2.2_three_layered_modules/ -d

2.2_three_layered_modules/
├── composition
│   ├── us-east-1
│   │   ├── prod
│   │   │   └── main.tf # <---main entrypoint calling infra-module
│   │   └── staging                                       |
│   └── us-west-2                                         |
├── infra_module                                          |
│   ├── app # this will wrap multiple resource modules  <--
│   ├── bastion                                   |
│   ├── elb                                       |
│   └── rds                                       |
└── resource_module                               |
    ├── compute                                   |
    │   ├── ec2 # <-------------------------------|
    │   ├── ec2_key_pair # <----------------------|
    │   ├── security_group  # <-------------------|
    │   └── ssm # <-------------------------------|
    ├── network
    │   ├── route53
    │   │   ├── hosted_zone
    │   │   └── record
    │   └── vpc
    └── storage
        ├── dynamodb
        ├── efs
        └── s3
```


## 3. Production-ready best practices of EKS (security, IRSA, CA, EFS, Logging etc)

In this course, we are going in parallel with my other course "__AWS EKS Handson__" when it comes to EKS best practices.

We will cover:
- encrypting K8s secrets and EBS volumes
- AWS identity authentication & authorization into K8s cluster
- adding taints and labels to K8s worker nodes from Terraform
- enabling master node's logging
- pod-level AWS IAM role (IRSA)
- Cluster Autoscaler
- customizing EKS worker node's userdata script to auto-mount EFS
all using terraform code.

![alt text](imgs/eks_irsa_2.png "")

Here is the code excerpt for adding AWS IAM roles to aws-auth configmap using Terraform: [7_security_user_authentication_authorization/composition/eks-demo-infra/ap-northeast-1/prod/data.tf](7_security_user_authentication_authorization/composition/eks-demo-infra/ap-northeast-1/prod/data.tf)
```sh
map_roles = var.authenticate_using_role == true ? concat(var.map_roles, [
    {
      rolearn  = "arn:aws:iam::${data.aws_caller_identity.this.account_id}:role/${var.role_name}"
      username = "k8s_terraform_builder"
      groups   = ["system:masters"] # k8s group name
    },
    {
      rolearn  = "arn:aws:iam::${data.aws_caller_identity.this.account_id}:role/Developer" # create Developer IAM role in Console
      username = "k8s-developer"
      groups   = ["k8s-developer"]
    },
  ]) : var.map_roles
```


## 4. Level up your DevOps game to Senior level and get promoted & raise

Terraform & EKS knowledge and skills you will acquire from this course will put you on a fast-tracked path to a senior level DevOps.

With these handson skills, you can make real and immediate impacts to your work. It's only a matter of time before you can discuss your next promotion and raise with your manager!



## 5. Entire course under 6 HOURS
I tried to make this course compact and concise so students can learn the concepts and handson skills in shorted amount of time, because I know a life of software engineer is already pretty busy :)



# My background & Education & Career experience
- Cloud DevOps Software Engineer with 7+ years experience
- Bachelor of Science in Computing Science from a Canadian university
- Knows Java, C#, C++, Bash, Python, JavaScript, Terraform, IaC, K8s, Docker
- Expert in AWS (holds AWS DevOps Professional certification) and Kubernetes (holds Certified Kubernetes Administrator, CKA, and CKAD)


I will see you inside!