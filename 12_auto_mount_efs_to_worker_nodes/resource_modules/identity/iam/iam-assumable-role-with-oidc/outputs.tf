output "arn" {
  description = "ARN of IAM role"
  value       = element(concat(aws_iam_role.this.*.arn, [""]), 0)
}

output "name" {
  description = "Name of IAM role"
  value       = element(concat(aws_iam_role.this.*.name, [""]), 0)
}

output "path" {
  description = "Path of IAM role"
  value       = element(concat(aws_iam_role.this.*.path, [""]), 0)
}