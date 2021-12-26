########################################
# Variables
########################################

variable "name" {
  description = "The name of the role."
  type = string
}

variable "tags" {
  description = "Key-value mapping of tags for the IAM role."
  type = map
}

variable "assume_role_policy_name" {
  description = "The name of the assume role policy. If omitted, Terraform will assign a random, unique name."
  type = string
}

variable "assume_role_policy_document" {
  description = "The assume role policy document. This is a JSON formatted string."
  type = string
}

variable "policies" {
  description = "The policies you want to create and apply. Must contains field name and policy as the JSON formated string."
  default     = []
}

variable "policies_count" {
  description = "Used to get around terraform bug of not being able to count a list of maps"
  type = string
}

variable "policies_arns" {
  description = "The ARNs of the policies you want to apply"
  type = list
}
