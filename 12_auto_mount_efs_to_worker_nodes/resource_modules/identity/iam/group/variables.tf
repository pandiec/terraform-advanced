########################################
# Variables
########################################

variable "name" {
  description = "The group's name. The name must consist of upper and lowercase alphanumeric characters with no spaces."
  type = string
}

variable "policies" {
  description = "The policies you want to create and apply. Must contains field name and policy as the JSON formated string."
  default     = []
}

variable "policies_count" {
  description = "Used to get around terraform bug of not being able to count a list of maps"
  type = string
  default     = 0
}

variable "policies_arns" {
  description = "The list of ARN of the policies you want to apply."
  type = list
}

variable "iam_group_membership_name" {
  description = "(Required) The name to identify the Group Membership"
}
variable "users" {
  description = "(Required) A list of IAM User names to associate with the Group"
  type = list
}