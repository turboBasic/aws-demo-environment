################################################################################
# EC2 Instance
################################################################################

resource "aws_instance" "demo" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = module.networking.private_subnet_a_id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  user_data              = file("${path.module}/scripts/user_data.sh")

  tags = merge(local.common_tags, local.auto_destroy_tags, {
    Name = "${local.name_prefix}-instance"
  })
}

################################################################################
# Target Group Attachment (connects EC2 to ALB)
################################################################################

resource "aws_lb_target_group_attachment" "demo" {
  target_group_arn = module.application_load_balancer.target_group_arn
  target_id        = aws_instance.demo.id
  port             = 80
}
