output "nat_gateway_id" {
  description = "The ID of the NAT Gateway"
  value       = aws_nat_gateway.main.id
}

output "nat_eip_id" {
  description = "The ID of the NAT Gateway Elastic IP"
  value       = aws_eip.nat.id
}

output "nat_eip_public_ip" {
  description = "The public IP address of the NAT Gateway"
  value       = aws_eip.nat.public_ip
}
