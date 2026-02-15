output "instance_id" {
  description = "The ID of the EC2 instance"
  value       = aws_instance.demo.id
}

output "instance_private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.demo.private_ip
}

output "instance_arn" {
  description = "ARN of the EC2 instance"
  value       = aws_instance.demo.arn
}

output "security_group_id" {
  description = "The security group ID of the EC2 instance"
  value       = aws_security_group.ec2.id
}
