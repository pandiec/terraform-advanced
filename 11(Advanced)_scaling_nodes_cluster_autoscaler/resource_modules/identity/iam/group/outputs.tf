########################################
# Outputs
########################################

output "name" {
  description = "The group's name."
  value       = aws_iam_group.this.name
}

output "id" {
  description = "The group's ID."
  value       = aws_iam_group.this.id
}

output "arn" {
  description = "The ARN assigned by AWS for this group."
  value       = aws_iam_group.this.arn
}

output "iam_group_membership_name" {
  description = "The name to identify the Group Membership"
  value       = aws_iam_group_membership.this.name
}
output "iam_group_users" {
  description = "list of IAM User names"
  value       = aws_iam_group_membership.this.users
}
output "iam_group" {
  description = "IAM Group name"
  value       = aws_iam_group_membership.this.group
}