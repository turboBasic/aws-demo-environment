output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "internet_gateway_id" {
  description = "The ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value       = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

output "public_subnet_a_id" {
  description = "The ID of public subnet A"
  value       = aws_subnet.public_a.id
}

output "public_subnet_b_id" {
  description = "The ID of public subnet B"
  value       = aws_subnet.public_b.id
}

output "private_subnet_ids" {
  description = "List of IDs of private subnets"
  value       = [aws_subnet.private_a.id]
}

output "private_subnet_a_id" {
  description = "The ID of private subnet A"
  value       = aws_subnet.private_a.id
}

output "nat_gateway_id" {
  description = "The ID of the NAT Gateway (if created)"
  value       = var.create_nat_gateway ? module.nat_gateway[0].nat_gateway_id : null
}

output "nat_eip_id" {
  description = "The ID of the NAT Gateway Elastic IP (if created)"
  value       = var.create_nat_gateway ? module.nat_gateway[0].nat_eip_id : null
}

output "nat_eip_public_ip" {
  description = "The public IP address of the NAT Gateway (if created)"
  value       = var.create_nat_gateway ? module.nat_gateway[0].nat_eip_public_ip : null
}

output "public_route_table_id" {
  description = "The ID of the public route table"
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "The ID of the private route table"
  value       = aws_route_table.private.id
}

output "s3_vpc_endpoint_id" {
  description = "The ID of the S3 VPC endpoint"
  value       = aws_vpc_endpoint.s3.id
}
