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