# NAT Gateway Module

Provides NAT Gateway resources for private subnet internet access. This module is designed to be conditionally used by the networking module.

## Features

- Elastic IP for NAT Gateway
- NAT Gateway in a public subnet
- Route entry in private route table pointing to NAT Gateway
- Auto-destroy tags for cost-saving ephemeral environments

## Architecture

```plaintext
┌─────────────────────────────────────────┐
│           Internet Gateway              │
└──────────────────┬──────────────────────┘
                   │
┌──────────────────▼──────────────────────┐
│          Public Subnet A                │
│  ┌────────────────────────────────┐     │
│  │      NAT Gateway               │     │
│  │  (Elastic IP attached)         │     │
│  └─────────────────┬──────────────┘     │
└────────────────────┼────────────────────┘
                     │
                     │ 0.0.0.0/0
                     │
┌────────────────────▼────────────────────┐
│     Private Route Table                 │
│  (route to 0.0.0.0/0 → NAT Gateway)     │
└────────────────────┬────────────────────┘
                     │
           ┌─────────▼─────────┐
           │  Private Subnets  │
           │ (internet access) │
           └───────────────────┘
```

## Usage

This module is typically called from the `networking` module:

```hcl
module "nat_gateway" {
  source = "./modules/networking-nat-gw"
  count  = var.create_nat_gateway ? 1 : 0

  name_prefix            = var.name_prefix
  public_subnet_id       = aws_subnet.public_a.id
  private_route_table_id = aws_route_table.private.id
  internet_gateway_id    = aws_internet_gateway.main.id

  tags = merge(var.tags, var.auto_destroy_tags)
}
```

## Inputs

| Name | Description | Type | Required |
| ---- | ----------- | ---- | -------- |
| name_prefix | Prefix for resource names | string | yes |
| public_subnet_id | Public subnet ID for NAT Gateway | string | yes |
| private_route_table_id | Private route table ID | string | yes |
| internet_gateway_id | Internet Gateway ID (for dependency) | string | yes |
| tags | Common tags (includes auto-destroy if merged by caller) | map(string) | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| nat_gateway_id | NAT Gateway ID |
| nat_eip_id | Elastic IP ID |
| nat_eip_public_ip | NAT Gateway public IP |

## Resources Created

- 1 Elastic IP (auto-destroy tagged)
- 1 NAT Gateway (auto-destroy tagged)
- 1 Route in private route table

## Cost Considerations

**NAT Gateway Pricing (eu-central-1):**

- Per hour: ~$0.045/hour
- Per day: ~$1.08/day
- Data processing: $0.045 per GB

**Total estimated cost**: ~$1.08/day for NAT Gateway (plus data transfer)

**Note**: This is the most expensive component in the demo environment. Set `create_nat_gateway = false` to save costs when private subnet internet access is not needed.

## When to Enable

Enable NAT Gateway (`create_nat_gateway = true`) when:

- EC2 instances in private subnets need internet access
- Private resources need to download packages/updates
- Private resources need to access external APIs

Disable NAT Gateway (`create_nat_gateway = false`) when:

- Using Fargate in public subnets (with public IPs)
- No private subnet internet access required
- Cost optimization is priority

## Notes

- NAT Gateway is placed in `public_a` subnet
- Single NAT Gateway (not HA across AZs) to minimize costs
- For production, consider multi-AZ NAT Gateway deployment
