# Networking Module

Complete VPC networking infrastructure for AWS applications with optional NAT Gateway.

## Features

- VPC with DNS support and hostnames enabled
- Internet Gateway for public internet access
- **Optional NAT Gateway** (conditional, disabled by default to save costs)
- Multi-AZ public subnets (required for Application Load Balancer)
- Private subnet for application instances
- Route tables with appropriate routing rules
- S3 VPC Gateway Endpoint for cost-efficient S3 access

## Architecture

```
┌───────────────────────────────────────────────────────────┐
│                         VPC (10.0.0.0/16)                 │
│                                                           │
│  ┌────────────────────┐         ┌────────────────────┐    │
│  │  Public Subnet A   │         │  Public Subnet B   │    │
│  │   (10.0.1.0/24)    │         │   (10.0.2.0/24)    │    │
│  │   AZ-a             │         │   AZ-b             │    │
│  │                    │         │                    │    │
│  │  ┌─────────────┐   │         │                    │    │
│  │  │ NAT Gateway │   │         │                    │    │
│  │  │  (optional) │   │         │                    │    │
│  │  └─────────────┘   │         │                    │    │
│  └──────────┬─────────┘         └────────────────────┘    │
│             │                                             │
│             │ Internet Gateway                            │
│             │                                             │
│  ┌──────────▼─────────┐                                   │
│  │  Private Subnet A  │                                   │
│  │   (10.0.10.0/24)   │                                   │
│  │   AZ-a             │                                   │
│  │                    │                                   │
│  │  [Workloads]       │  (Internet via NAT if enabled)    │
│  └────────────────────┘                                   │
│                                                           │
│  S3 VPC Endpoint (Gateway) ───────────────┐               │
│                                           │               │
└───────────────────────────────────────────┼───────────────┘
                                            │
                                     ┌──────▼──────┐
                                     │   Amazon    │
                                     │     S3      │
                                     └─────────────┘
```

## Usage

```hcl
module "networking" {
  source = "./modules/networking"

  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24"]
  region               = "eu-central-1"
  name_prefix          = "my-app-demo"
  create_nat_gateway   = false  # Set to true to enable NAT Gateway (+$1/day)

  tags = {
    Environment = "demo"
    Project     = "my-app"
    ManagedBy   = "terraform"
  }

  auto_destroy_tags = {
    AutoDestroy = "true"
  }
}
```

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| vpc_cidr | CIDR block for the VPC | string | yes |
| public_subnet_cidrs | CIDR blocks for public subnets | list(string) | yes |
| private_subnet_cidrs | CIDR blocks for private subnets | list(string) | yes |
| region | AWS region for service endpoints | string | yes |
| name_prefix | Prefix for resource names | string | yes |
| create_nat_gateway | Enable NAT Gateway (adds ~$1/day cost) | bool | no (default: false) |
| tags | Common tags for all resources | map(string) | no |
| auto_destroy_tags | Tags for ephemeral resources | map(string) | no |

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | VPC identifier |
| vpc_cidr_block | VPC CIDR block |
| public_subnet_ids | List of public subnet IDs |
| private_subnet_ids | List of private subnet IDs |
| nat_gateway_id | NAT Gateway identifier (null if disabled) |
| nat_eip_id | NAT Gateway Elastic IP ID (null if disabled) |
| nat_eip_public_ip | NAT Gateway public IP (null if disabled) |
| public_route_table_id | Public route table ID |
| private_route_table_id | Private route table ID |
| s3_vpc_endpoint_id | S3 VPC endpoint ID |

## Resources Created

### Always Created
- 1 VPC
- 1 Internet Gateway
- 2 Public Subnets (multi-AZ)
- 1 Private Subnet
- 2 Route Tables (public and private)
- 3 Route Table Associations
- 1 S3 VPC Gateway Endpoint

### Conditionally Created (when `create_nat_gateway = true`)
- 1 Elastic IP (for NAT)
- 1 NAT Gateway
- 1 Route (0.0.0.0/0 → NAT Gateway in private route table)

## Cost Considerations

**Without NAT Gateway** (`create_nat_gateway = false`):
- No hourly NAT Gateway charges
- Private subnet has no internet access
- Suitable for Fargate in public subnets

**With NAT Gateway** (`create_nat_gateway = true`):
- ~$0.045/hour (~$1.08/day) for NAT Gateway
- $0.045 per GB data processed
- Private subnet can access internet
- Suitable for EC2 instances needing updates/packages

## Notes

- **Multi-AZ Design**: Two public subnets across different AZs are required for Application Load Balancer
- **NAT Gateway**: When enabled, allows private subnet instances to access internet for updates/downloads
- **S3 Endpoint**: Gateway endpoint avoids NAT charges for S3 traffic from private subnet
- **DNS Settings**: Both DNS support and hostnames are enabled for service discovery
- **Cost Optimization**: Default is `create_nat_gateway = false` to minimize costs in demo environments
- **Cost Optimization**: NAT Gateway is the primary cost driver (~$32/month + data transfer)

## Dependencies

- AWS Provider configured with appropriate credentials
- At least 2 availability zones in the target region

## Example: Complete Root Module Integration

```hcl
# Query available AZs
data "aws_availability_zones" "available" {
  state = "available"
}

# Create networking infrastructure
module "networking" {
  source = "./modules/networking"

  vpc_cidr             = var.vpc_cidr
  availability_zones   = data.aws_availability_zones.available.names
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24"]
  region               = var.aws_region
  name_prefix          = "${var.project_name}-${var.environment}"

  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }

  auto_destroy_tags = {
    AutoDestroy = "true"
  }
}

# Use outputs in other resources
resource "aws_security_group" "example" {
  vpc_id = module.networking.vpc_id
  # ...
}
```
