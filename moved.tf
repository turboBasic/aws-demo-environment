################################################################################
# Moved Blocks for Networking Module Migration
# These blocks ensure zero downtime by telling Terraform about the resource
# address changes when transitioning from root module to modules/networking
#
# Apply these moved blocks BEFORE removing the old resource definitions
################################################################################

moved {
  from = aws_vpc.main
  to   = module.networking.aws_vpc.main
}

moved {
  from = aws_internet_gateway.main
  to   = module.networking.aws_internet_gateway.main
}

moved {
  from = aws_subnet.public_a
  to   = module.networking.aws_subnet.public_a
}

moved {
  from = aws_subnet.public_b
  to   = module.networking.aws_subnet.public_b
}

moved {
  from = aws_subnet.private_a
  to   = module.networking.aws_subnet.private_a
}

moved {
  from = aws_eip.nat
  to   = module.networking.aws_eip.nat
}

moved {
  from = aws_nat_gateway.main
  to   = module.networking.aws_nat_gateway.main
}

moved {
  from = aws_route_table.public
  to   = module.networking.aws_route_table.public
}

moved {
  from = aws_route_table.private
  to   = module.networking.aws_route_table.private
}

moved {
  from = aws_route_table_association.public_a
  to   = module.networking.aws_route_table_association.public_a
}

moved {
  from = aws_route_table_association.public_b
  to   = module.networking.aws_route_table_association.public_b
}

moved {
  from = aws_route_table_association.private_a
  to   = module.networking.aws_route_table_association.private_a
}

moved {
  from = aws_vpc_endpoint.s3
  to   = module.networking.aws_vpc_endpoint.s3
}
################################################################################
# Moved Blocks for ALB Module Migration
# These blocks ensure zero downtime by telling Terraform about the resource
# address changes when transitioning from root module to modules/application-load-balancer
################################################################################

moved {
  from = aws_security_group.alb
  to   = module.application_load_balancer.aws_security_group.alb
}

moved {
  from = aws_vpc_security_group_ingress_rule.alb_https
  to   = module.application_load_balancer.aws_vpc_security_group_ingress_rule.alb_https
}

moved {
  from = aws_vpc_security_group_ingress_rule.alb_http
  to   = module.application_load_balancer.aws_vpc_security_group_ingress_rule.alb_http
}

moved {
  from = aws_vpc_security_group_egress_rule.alb_all
  to   = module.application_load_balancer.aws_vpc_security_group_egress_rule.alb_all
}

moved {
  from = aws_lb.demo
  to   = module.application_load_balancer.aws_lb.demo
}

moved {
  from = aws_lb_target_group.demo
  to   = module.application_load_balancer.aws_lb_target_group.demo
}

moved {
  from = aws_lb_listener.http
  to   = module.application_load_balancer.aws_lb_listener.http
}

moved {
  from = aws_lb_listener.https
  to   = module.application_load_balancer.aws_lb_listener.https
}

moved {
  from = aws_lb_listener_rule.cloudfront_origin
  to   = module.application_load_balancer.aws_lb_listener_rule.cloudfront_origin
}
