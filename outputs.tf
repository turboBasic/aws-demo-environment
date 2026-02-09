output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.demo.dns_name
}

output "ec2_instance_id" {
  description = "ID of the demo EC2 instance"
  value       = aws_instance.demo.id
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}
