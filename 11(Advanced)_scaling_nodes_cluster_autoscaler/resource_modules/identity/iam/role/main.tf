########################################
# AWS IAM Role resource
#
# https://www.terraform.io/docs/providers/aws/r/iam_role.html
# https://www.terraform.io/docs/providers/aws/r/iam_policy.html
# https://www.terraform.io/docs/providers/aws/r/iam_role_policy_attachment.html
########################################

resource "aws_iam_role" "this" {
  name               = var.name
  assume_role_policy = var.assume_role_policy_document
  tags               = var.tags
}

resource "aws_iam_policy" "this" {
  count  = var.policies_count
  name   = lookup(var.policies[count.index], "name")
  policy = lookup(var.policies[count.index], "policy")
}

resource "aws_iam_role_policy_attachment" "this" {
  count      = local.policy_attachment_count
  role       = aws_iam_role.this.name
  policy_arn = local.policies_arns[count.index]
}
