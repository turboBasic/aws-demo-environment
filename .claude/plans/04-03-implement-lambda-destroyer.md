# Plan: Implement Lambda Destroyer

## Context

Create the Lambda function that checks Terraform state age and removes expensive demo resources when the TTL expires. Uses native AWS API calls to delete tagged resources directly.

For architecture context, see [04-00-aws-demo-environment-architecture.md](04-00-aws-demo-environment-architecture.md).
For Lambda infrastructure (IAM, EventBridge), see [04-02-implement-bootstrap-module.md](04-02-implement-bootstrap-module.md).

## Design

- **Deployment**: Zip-based via `archive_file` provider
- **Runtime**: Python 3.12 with pre-installed boto3
- **Resource discovery**: Resource Groups Tagging API with `AutoDestroy=true` tag
- **Destruction**: Direct AWS API calls in dependency order

## Steps

- [x] Create `bootstrap/lambda-destroyer/handler.py` — TTL check via S3 HeadObject, tag-based resource discovery, ordered resource deletion via native AWS APIs

## Handler Logic

1. Check S3 state file `LastModified` age against `TTL_MINUTES` env var
2. Skip if no state file or TTL not expired
3. Discover resources tagged `AutoDestroy=true` via Resource Groups Tagging API
4. Classify resources by type (ALB, target groups, EC2, NAT GW, EIPs)
5. Delete in dependency order: ALBs → target groups → EC2 instances → NAT gateways → EIPs
6. Return status (`skip`, `destroyed`, `partial`) with metrics

## Status: Completed
