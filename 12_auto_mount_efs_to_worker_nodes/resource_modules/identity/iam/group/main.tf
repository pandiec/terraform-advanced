########################################
# AWS IAM Group resource
#
# https://www.terraform.io/docs/providers/aws/r/iam_group.html
########################################

resource "aws_iam_group" "this" {
  name = var.name
}

resource "aws_iam_policy" "this" {
  count  = var.policies_count
  name   = lookup(var.policies[count.index], "name")
  policy = lookup(var.policies[count.index], "policy")
}

resource "aws_iam_group_policy_attachment" "this" {
  count      = local.policy_attachment_count
  group      = aws_iam_group.this.name
  policy_arn = local.policies_arns[count.index]
}

resource "aws_iam_group_membership" "this" {
  name = var.iam_group_membership_name

  users = var.users
  group = aws_iam_group.this.name
}