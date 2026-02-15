################################################################################
# Target Group Attachment (connects EC2 to ALB)
################################################################################

resource "aws_lb_target_group_attachment" "demo" {
  target_group_arn = module.application_load_balancer.target_group_arn
  target_id        = module.web_instance.instance_id
  port             = 80
}
