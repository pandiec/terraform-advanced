########################################
# Data sources
########################################

# Computed variables
locals {
  policies_arns           = compact(concat(var.policies_arns, aws_iam_policy.this.*.arn))
  policy_attachment_count = length(var.policies_arns) + var.policies_count
}
