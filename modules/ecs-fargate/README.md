# ECS Fargate Module

Self-contained ECS Fargate service with ALB integration for containerized workloads.

## Features

- ECS cluster with Fargate launch type
- Task definition with CloudWatch logging
- ECS service in public subnets with auto-assigned public IPs
- IAM role for task execution (ECR pull, CloudWatch logs)
- Security group allowing HTTP traffic from ALB only
- Automatic ALB target group integration

## Architecture

```plaintext
┌──────────────────────────────────────┐
│      Application Load Balancer       │
│    (module.application_load_balancer)│
└────────────────┬─────────────────────┘
                 │ HTTP (Port 80)
                 │
┌────────────────▼─────────────────────┐
│  ECS Tasks Security Group (Module)   │
│  - Ingress: HTTP from ALB            │
│  - Egress: All traffic to anywhere   │
└────────────────┬─────────────────────┘
                 │
        ┌────────▼────────┐
        │  ECS Fargate    │
        │  Public Subnet  │
        │  (httpd:2.4)    │
        │  Public IP      │
        └────────┬────────┘
                 │
                 ▼
          Internet Gateway
```

## Usage

```hcl
module "ecs_fargate" {
  source = "./modules/ecs-fargate"

  name_prefix           = "my-app-demo"
  vpc_id                = module.networking.vpc_id
  public_subnet_ids     = module.networking.public_subnet_ids
  alb_security_group_id = module.application_load_balancer.alb_security_group_id
  target_group_arn      = module.application_load_balancer.target_group_arn
  region                = var.aws_region

  container_image = "httpd:2.4"
  container_port  = 80
  task_cpu        = "256"  # 0.25 vCPU
  task_memory     = "512"  # 512 MB
  desired_count   = 1

  tags = local.common_tags

  auto_destroy_tags = local.auto_destroy_tags
}
```

## Inputs

| Name | Description | Type | Required |
| ---- | ----------- | ---- | -------- |
| name_prefix | Prefix for resource names | string | yes |
| vpc_id | VPC ID for security group | string | yes |
| public_subnet_ids | Public subnet IDs for tasks | list(string) | yes |
| alb_security_group_id | ALB security group for ingress | string | yes |
| target_group_arn | ALB target group ARN | string | yes |
| region | AWS region for CloudWatch logs | string | yes |
| container_image | Docker image | string | no (default: httpd:2.4) |
| container_port | Container port | number | no (default: 80) |
| task_cpu | CPU units (256, 512, 1024, etc.) | string | no (default: 256) |
| task_memory | Memory in MB | string | no (default: 512) |
| desired_count | Number of tasks | number | no (default: 1) |
| environment_variables | Container environment vars | list(object) | no |
| tags | Common tags | map(string) | no |
| auto_destroy_tags | Tags for auto-destroy (applied to expensive resources) | map(string) | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| cluster_arn | ECS cluster ARN |
| service_arn | ECS service ARN |
| service_name | ECS service name |
| security_group_id | Security group ID |
| log_group_name | CloudWatch log group name |

## Resources Created

- 1 ECS Cluster (auto-destroy tagged)
- 1 ECS Task Definition (auto-destroy tagged)
- 1 ECS Service (auto-destroy tagged)
- 1 CloudWatch Log Group
- 1 IAM Role (task execution)
- 1 IAM Role Policy Attachment
- 1 Security Group
- 2 Security Group Rules

**Note**: Only expensive compute resources (cluster, task definition, service) are tagged with `auto_destroy_tags` for Lambda cleanup. Supporting resources (IAM, security groups, logs) use `tags` only.

## Cost Considerations

**Fargate Pricing (us-east-1):**

- 256 CPU / 512 MB: ~$0.01232/hour = **$0.30/day**
- No NAT Gateway charges (public subnet with Internet Gateway)
- CloudWatch Logs: Free tier 5GB/month

**Comparison to EC2 + NAT:**

- Old: t3.micro ($0.0104/h) + NAT ($0.045/h) = ~$1.35/day
- New: Fargate = ~$0.30/day
- **Savings: ~78%**

## Security Considerations

1. **Public Subnet with Public IP**: Tasks get public IPs for internet access (no NAT required)
2. **ALB-Only Access**: Security group allows HTTP only from ALB
3. **No SSH Access**: Immutable infrastructure, no remote login
4. **CloudWatch Logging**: All container logs sent to CloudWatch

## Notes

- Uses `httpd:2.4` from Docker Hub (public registry, no ECR setup needed)
- Task execution role allows ECR pulls and CloudWatch log writes
- `assign_public_ip = true` enables internet access without NAT Gateway
- Target group automatically registers Fargate task IPs (not instance IDs)
