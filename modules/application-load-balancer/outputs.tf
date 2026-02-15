output "alb_id" {
  description = "The ID of the Application Load Balancer"
  value       = aws_lb.demo.id
}

output "alb_arn" {
  description = "The ARN of the Application Load Balancer"
  value       = aws_lb.demo.arn
}

output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer"
  value       = aws_lb.demo.dns_name
}

output "alb_zone_id" {
  description = "The zone ID of the Application Load Balancer"
  value       = aws_lb.demo.zone_id
}

output "alb_security_group_id" {
  description = "The security group ID of the Application Load Balancer"
  value       = aws_security_group.alb.id
}

output "target_group_arn" {
  description = "The ARN of the target group"
  value       = aws_lb_target_group.demo.arn
}

output "target_group_name" {
  description = "The name of the target group"
  value       = aws_lb_target_group.demo.name
}

output "http_listener_arn" {
  description = "The ARN of the HTTP listener"
  value       = aws_lb_listener.http.arn
}

output "https_listener_arn" {
  description = "The ARN of the HTTPS listener"
  value       = aws_lb_listener.https.arn
}
