################################################################################
# EC2 Instance
################################################################################

resource "aws_instance" "demo" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private_a.id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  user_data              = file("${path.module}/scripts/user_data.sh")

  tags = merge(local.common_tags, local.auto_destroy_tags, {
    Name = "${local.name_prefix}-instance"
  })
}

################################################################################
# Application Load Balancer
################################################################################

resource "aws_lb" "demo" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]

  enable_deletion_protection = true

  tags = merge(local.common_tags, local.auto_destroy_tags, {
    Name = "${local.name_prefix}-alb"
  })
}

resource "aws_lb_target_group" "demo" {
  name     = "${local.name_prefix}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = merge(local.common_tags, local.auto_destroy_tags, {
    Name = "${local.name_prefix}-tg"
  })
}

resource "aws_lb_target_group_attachment" "demo" {
  target_group_arn = aws_lb_target_group.demo.arn
  target_id        = aws_instance.demo.id
  port             = 80
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.demo.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-http-listener"
  })
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.demo.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate_validation.demo.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.demo.arn
  }
}
