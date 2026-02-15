# Application Load Balancer Module

Complete ALB infrastructure with multi-AZ deployment, SSL/HTTPS termination, and origin verification.

## Features

- Multi-AZ Application Load Balancer with deletion protection
- Dedicated security group with ingress rules for HTTP/HTTPS
- HTTP listener with automatic redirect to HTTPS
- HTTPS listener with SSL/TLS certificate support
- Target group with configurable health checks
- Listener rule for CloudFront origin verification via custom header
- Automatic deprecation of direct access when using CloudFront

## Architecture

```
┌──────────────────────────────────────────┐
│         Internet / CloudFront            │
└───────────────────┬──────────────────────┘
                    │
                    ▼
         ┌──────────────────────┐
         │   ALB Security Group │
         │ (HTTP/HTTPS ingress) │
         └──────────┬───────────┘
                    │
    ┌───────────────┴────────────────┐
    │                                │
    ▼ (Multi-AZ)                     ▼
┌─────────────────────┐        ┌─────────────────────┐
│  Public Subnet A    │        │  Public Subnet B    │
│                     │        │                     │
│    ALB (Port 80)    │────────│    ALB (Port 80)    │
│    ALB (Port 443)   │        │    ALB (Port 443)   │
└────────┬────────────┘        └────────┬────────────┘
         │                              │
         └──────────────┬───────────────┘
                        │
            ┌───────────▼────────────┐
            │    Target Group        │
            │ (Port 80 to EC2)       │
            │ Health Checks Every 30s│
            └───────────┬────────────┘
                        │
                        ▼
            ┌───────────────────────┐
            │    EC2 Instance       │
            │  (in Private Subnet)  │
            └───────────────────────┘
```

## Origin Verification Strategy

The module includes a listener rule that validates the `X-Origin-Verify` custom header:

- ✅ Requests with valid header → forwarded to target group
- ❌ Direct requests (no header) → 403 Forbidden
- 🔐 Requires CloudFront to inject the header (configured in CDN module)

This approach avoids AWS security group rule quotas that would be exceeded by listing all CloudFront IP ranges.

## Usage

```hcl
module "alb" {
  source = "./modules/application-load-balancer"

  vpc_id              = module.networking.vpc_id
  public_subnet_ids   = module.networking.public_subnet_ids
  certificate_arn     = module.certificates.regional_certificate_arn
  origin_verify_header = random_password.origin_verify.result

  name_prefix   = "my-app-demo"
  tags          = local.common_tags
  auto_destroy_tags = {
    AutoDestroy = "true"
  }
}
```

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| vpc_id | VPC ID for ALB and target group | string | yes |
| public_subnet_ids | List of public subnet IDs (min 2 for multi-AZ) | list(string) | yes |
| certificate_arn | ARN of SSL/TLS certificate for HTTPS | string | yes |
| origin_verify_header | Custom header value for CloudFront verification | string | yes |
| name_prefix | Prefix for resource names | string | yes |
| tags | Common tags for all resources | map(string) | no |
| auto_destroy_tags | Tags for ephemeral resources | map(string) | no |

## Outputs

| Name | Description |
|------|-------------|
| alb_id | ALB identifier |
| alb_arn | ALB ARN |
| alb_dns_name | ALB DNS name (for Cloudflare CNAME) |
| alb_zone_id | ALB hosted zone ID |
| alb_security_group_id | ALB security group ID |
| target_group_arn | Target group ARN |
| target_group_name | Target group name |
| http_listener_arn | HTTP listener ARN |
| https_listener_arn | HTTPS listener ARN |

## Resources Created

- 1 Security Group (ALB)
- 3 Security Group Rules (HTTP, HTTPS ingress, all egress)
- 1 Application Load Balancer (multi-AZ)
- 1 Target Group
- 1 HTTP Listener (redirect to HTTPS)
- 1 HTTPS Listener
- 1 Listener Rule (CloudFront verification)

## Listener Configuration

### HTTP Listener (Port 80)
- Default action: Redirect to HTTPS (HTTP 301)
- Allows unencrypted traffic to be upgraded automatically

### HTTPS Listener (Port 443)
- Uses provided SSL certificate for TLS termination
- Default action: Fixed response (403) for direct access
- Listener rule: Forward to target group only if `X-Origin-Verify` header matches

## Health Checks

Target group health checks configured with:
- Path: `/`
- Protocol: HTTP
- Healthy threshold: 2 consecutive successes
- Unhealthy threshold: 3 consecutive failures
- Interval: 30 seconds
- Timeout: 5 seconds
- Success codes: 200

## Security Considerations

1. **Deletion Protection**: Enabled to prevent accidental ALB deletion
2. **Direct Access Prevention**: Fixed response on direct access attempts
3. **CloudFront Validation**: Custom header ensures requests originate from CloudFront
4. **Security Group Scoping**: Minimal ingress rules (0.0.0.0/0) with application-level validation
5. **HTTPS Enforcement**: HTTP listener redirects all traffic to HTTPS

## Notes

- Requires a valid SSL/TLS certificate ARN (typically from ACM)
- Origin verification header should be a strong random value (generated externally)
- Health check endpoint must respond with HTTP 200
- Target group attachment (EC2 linking) is managed in root module

## Next Steps

After creating this module, connect it to EC2 instances via:

```hcl
resource "aws_lb_target_group_attachment" "demo" {
  target_group_arn = module.alb.target_group_arn
  target_id        = module.web_instance.instance_id
  port             = 80
}
```
