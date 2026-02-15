################################################################################
# EC2 Security Group
################################################################################

resource "aws_security_group" "ec2" {
  name        = "${local.name_prefix}-ec2-sg"
  description = "Security group for the demo EC2 instance"
  vpc_id      = module.networking.vpc_id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ec2-sg"
  })
}

resource "aws_vpc_security_group_ingress_rule" "ec2_http_from_alb" {
  security_group_id            = aws_security_group.ec2.id
  description                  = "HTTP from ALB"
  referenced_security_group_id = module.application_load_balancer.alb_security_group_id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "ec2_all" {
  security_group_id = aws_security_group.ec2.id
  description       = "All outbound traffic"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
