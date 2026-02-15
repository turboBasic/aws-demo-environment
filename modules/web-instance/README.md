# Web Instance (EC2) Module

Self-contained EC2 instance with security group configuration for hosting application workloads.

## Features

- Amazon Linux 2023 EC2 instance in private subnet
- Dedicated security group with ingress from ALB only
- Automatic outbound internet access via NAT Gateway
- User data support for instance initialization
- Tagging support for lifecycle management and cost tracking

## Architecture

```
┌──────────────────────────────────────┐
│      Application Load Balancer       │
│    (module.application_load_balancer)│
└────────────────┬─────────────────────┘
                 │ HTTP (Port 80)
                 │
┌────────────────▼─────────────────────┐
│    EC2 Security Group (This Module)  │
│  - Ingress: HTTP from ALB            │
│  - Egress: All traffic to anywhere   │
└────────────────┬─────────────────────┘
                 │
        ┌────────▼────────┐
        │  EC2 Instance   │
        │  Private Subnet │
        │   (Amazon       │
        │   Linux 2023)   │
        └────────┬────────┘
                 │
                 ▼
        ┌────────────────┐
        │  NAT Gateway   │
        │   (Outbound)   │
        └────────────────┘
```

## Usage

```hcl
module "web_instance" {
  source = "./modules/web-instance"

  vpc_id                    = module.networking.vpc_id
  private_subnet_id         = module.networking.private_subnet_a_id
  ami_id                    = data.aws_ami.al2023.id
  instance_type             = "t3.micro"
  alb_security_group_id     = module.application_load_balancer.alb_security_group_id
  user_data                 = file("${path.module}/scripts/user_data.sh")

  name_prefix       = "my-app-demo"
  tags              = local.common_tags
  auto_destroy_tags = local.auto_destroy_tags
}

# Connect EC2 to ALB
resource "aws_lb_target_group_attachment" "demo" {
  target_group_arn = module.application_load_balancer.target_group_arn
  target_id        = module.web_instance.instance_id
  port             = 80
}
```

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| vpc_id | VPC ID for security group | string | yes |
| private_subnet_id | Private subnet for EC2 placement | string | yes |
| ami_id | AMI ID (typically Amazon Linux 2023) | string | yes |
| instance_type | EC2 instance type | string | no (default: t3.micro) |
| alb_security_group_id | ALB security group for ingress | string | yes |
| user_data | User data script for initialization | string | no |
| name_prefix | Prefix for resource names | string | yes |
| tags | Common tags for all resources | map(string) | no |
| auto_destroy_tags | Tags for ephemeral resources | map(string) | no |

## Outputs

| Name | Description |
|------|-------------|
| instance_id | EC2 instance ID |
| instance_private_ip | Private IP address |
| instance_arn | EC2 instance ARN |
| security_group_id | Security group ID |

## Resources Created

- 1 EC2 Instance
- 1 Security Group
- 2 Security Group Rules (HTTP ingress from ALB, all egress)

## Security Considerations

1. **Private Subnet Placement**: Instance runs in private subnet without public IP
2. **ALB-Only Access**: Security group allows HTTP traffic only from ALB
3. **Outbound Internet**: NAT Gateway provides secure egress for package updates and external calls
4. **No SSH Access**: No ingress rule for SSH (managed separately if needed)

## User Data

The module supports custom initialization scripts via `user_data` variable:

```hcl
user_data = file("${path.module}/scripts/user_data.sh")
```

Common tasks in user data:
- Install web server (Apache, Nginx)
- Update system packages
- Configure monitoring agents
- Deploy application code

## Target Group Attachment

To connect the EC2 instance to an ALB, use in root module:

```hcl
resource "aws_lb_target_group_attachment" "instance" {
  target_group_arn = module.application_load_balancer.target_group_arn
  target_id        = module.web_instance.instance_id
  port             = 80
}
```

## Cost Considerations

- **t3.micro**: Free tier eligible (first 750 hours/month for 12 months)
- **Data transfer**: Egress through NAT costs ~$0.045/GB
- **EBS volume**: 30GB free tier included

## Example with Multiple Instances

```hcl
module "web_instance_primary" {
  source = "./modules/web-instance"
  # ... configuration
}

module "web_instance_secondary" {
  source       = "./modules/web-instance"
  # ... configuration with different subnet
}

resource "aws_lb_target_group_attachment" "primary" {
  target_group_arn = module.application_load_balancer.target_group_arn
  target_id        = module.web_instance_primary.instance_id
  port             = 80
}

resource "aws_lb_target_group_attachment" "secondary" {
  target_group_arn = module.application_load_balancer.target_group_arn
  target_id        = module.web_instance_secondary.instance_id
  port             = 80
}
```

This approach enables easy scaling across multiple instances or AZs.
