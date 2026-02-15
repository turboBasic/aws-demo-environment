################################################################################
# AL2023 AMI Data Source
################################################################################

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  default_html = <<-HTML
  <!DOCTYPE html>
  <html lang="en">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>page is empty</title>
  </head>
  <body>
    <p>page is empty</p>
  </body>
  </html>
  HTML

  resolved_html      = var.html_content != "" ? var.html_content : local.default_html
  rendered_user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    html_content = local.resolved_html
  })
}

################################################################################
# EC2 Security Group
################################################################################

resource "aws_security_group" "ec2" {
  name        = "${var.name_prefix}-ec2-sg"
  description = "Security group for the demo EC2 instance"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ec2-sg"
  })
}

################################################################################
# EC2 Security Group Rules
################################################################################

resource "aws_vpc_security_group_ingress_rule" "ec2_http_from_alb" {
  security_group_id            = aws_security_group.ec2.id
  description                  = "HTTP from ALB"
  referenced_security_group_id = var.alb_security_group_id
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

################################################################################
# EC2 Instance
################################################################################

resource "aws_instance" "demo" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = var.private_subnet_id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  user_data              = local.rendered_user_data

  tags = merge(var.tags, var.auto_destroy_tags, {
    Name = "${var.name_prefix}-instance"
  })
}

################################################################################
# Target Group Attachment (connects EC2 to ALB)
################################################################################

resource "aws_lb_target_group_attachment" "demo" {
  target_group_arn = var.alb_target_group_arn
  target_id        = aws_instance.demo.id
  port             = 80
}
