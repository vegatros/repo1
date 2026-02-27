output "role_arn" {
  description = "ARN of the PowerUser role"
  value       = aws_iam_role.poweruser.arn
}

output "role_name" {
  description = "Name of the PowerUser role"
  value       = aws_iam_role.poweruser.name
}

output "assume_role_command" {
  description = "Command to assume this role"
  value       = "aws sts assume-role --role-arn ${aws_iam_role.poweruser.arn} --role-session-name poweruser-session"
}
