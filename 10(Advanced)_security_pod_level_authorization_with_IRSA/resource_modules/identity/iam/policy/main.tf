resource "aws_iam_policy" "this" {
  count       = var.create_policy ? 1 : 0
  description = var.description
  name        = var.name
  path        = var.path
  policy      = var.policy
}
