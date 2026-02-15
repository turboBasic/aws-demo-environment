"""Lambda handler that checks Terraform state age and destroys expensive tagged resources."""

import logging
import os
import time
from datetime import datetime, timezone

import boto3
from botocore.exceptions import ClientError, WaiterError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Environment variables
STATE_BUCKET = os.environ["STATE_BUCKET"]
STATE_KEY = os.environ["STATE_KEY"]
STATE_REGION = os.environ["STATE_REGION"]
TTL_MINUTES = int(os.environ["TTL_MINUTES"])

# Tag used to discover resources for auto-destruction
AUTO_DESTROY_TAG_KEY = "AutoDestroy"
AUTO_DESTROY_TAG_VALUE = "true"

# NAT Gateway deletion polling
NAT_GW_POLL_INTERVAL = 10  # seconds
NAT_GW_POLL_TIMEOUT = 300  # 5 minutes


def get_state_age_minutes() -> float | None:
    """Check the age of the Terraform state file in S3. Returns None if no state exists."""
    s3 = boto3.client("s3", region_name=STATE_REGION)
    try:
        response = s3.head_object(Bucket=STATE_BUCKET, Key=STATE_KEY)
    except ClientError as e:
        if e.response["Error"]["Code"] == "404":
            logger.info("No state file found at s3://%s/%s", STATE_BUCKET, STATE_KEY)
            return None
        raise

    last_modified = response["LastModified"]
    age = datetime.now(timezone.utc) - last_modified
    age_minutes = age.total_seconds() / 60
    logger.info(
        "State file last modified: %s (%.1f minutes ago)",
        last_modified.isoformat(),
        age_minutes,
    )
    return age_minutes


def discover_tagged_resources() -> dict[str, list[str]]:
    """Discover all resources tagged with AutoDestroy=true.

    Uses the Resource Groups Tagging API to find resources, then classifies
    them by type. Returns a dict mapping resource type to list of ARNs.
    """
    client = boto3.client("resourcegroupstaggingapi", region_name=STATE_REGION)
    resources_by_type: dict[str, list[str]] = {}

    paginator = client.get_paginator("get_resources")
    for page in paginator.paginate(
        TagFilters=[{"Key": AUTO_DESTROY_TAG_KEY, "Values": [AUTO_DESTROY_TAG_VALUE]}],
    ):
        for resource in page["ResourceTagMappingList"]:
            arn = resource["ResourceARN"]
            resource_type = _classify_resource(arn)
            if resource_type:
                resources_by_type.setdefault(resource_type, []).append(arn)
                logger.info("Discovered %s: %s", resource_type, arn)
            else:
                logger.warning("Unknown resource type for ARN: %s", arn)

    total = sum(len(v) for v in resources_by_type.values())
    logger.info("Discovered %d tagged resources across %d types", total, len(resources_by_type))
    return resources_by_type


def _classify_resource(arn: str) -> str | None:
    """Classify an ARN into a known resource type.

    ARN examples:
      arn:aws:elasticloadbalancing:region:account:loadbalancer/app/name/id
      arn:aws:elasticloadbalancing:region:account:targetgroup/name/id
      arn:aws:ec2:region:account:instance/i-xxxxx
      arn:aws:ec2:region:account:natgateway/nat-xxxxx
      arn:aws:ec2:region:account:elastic-ip/eipalloc-xxxxx
    """
    parts = arn.split(":")
    if len(parts) < 6:
        return None

    service = parts[2]
    resource_part = parts[5]

    if service == "elasticloadbalancing":
        if resource_part.startswith("loadbalancer/"):
            return "elasticloadbalancing:loadbalancer"
        if resource_part.startswith("targetgroup/"):
            return "elasticloadbalancing:targetgroup"
    elif service == "ecs":
        if resource_part.startswith("service/"):
            return "ecs:service"
    elif service == "ec2":
        if resource_part.startswith("instance/"):
            return "ec2:instance"
        if resource_part.startswith("natgateway/"):
            return "ec2:natgateway"
        if resource_part.startswith("elastic-ip/"):
            return "ec2:elastic-ip"

    return None


def _extract_id_from_arn(arn: str) -> str:
    """Extract the resource ID from the last segment of an ARN."""
    return arn.rsplit("/", 1)[-1]


def _extract_ecs_service_parts(arn: str) -> tuple[str, str]:
    """Extract ECS cluster name and service name from a service ARN."""
    resource = arn.split(":", 5)[-1]
    # resource format: service/cluster-name/service-name
    _, cluster_name, service_name = resource.split("/", 2)
    return cluster_name, service_name


def delete_ecs_services(arns: list[str]) -> None:
    """Delete ECS services to stop Fargate tasks before ALB cleanup."""
    client = boto3.client("ecs", region_name=STATE_REGION)
    max_retries = 10
    retry_delay = 10  # seconds

    for arn in arns:
        try:
            cluster_name, service_name = _extract_ecs_service_parts(arn)
        except ValueError:
            logger.error("Unexpected ECS service ARN format: %s", arn)
            continue

        try:
            logger.info("Scaling ECS service to 0: %s", arn)
            client.update_service(cluster=cluster_name, service=service_name, desiredCount=0)
        except ClientError as e:
            error_code = e.response.get("Error", {}).get("Code")
            if error_code == "ServiceNotFoundException":
                logger.info("ECS service %s already deleted", arn)
                continue
            logger.error("Failed to scale ECS service %s: %s", arn, e)

        for attempt in range(max_retries):
            try:
                logger.info("Deleting ECS service: %s (attempt %d/%d)", arn, attempt + 1, max_retries)
                client.delete_service(cluster=cluster_name, service=service_name, force=True)
                break
            except ClientError as e:
                error_code = e.response.get("Error", {}).get("Code")
                if error_code == "ServiceNotFoundException":
                    logger.info("ECS service %s already deleted", arn)
                    break
                if attempt < max_retries - 1:
                    logger.warning(
                        "Failed to delete ECS service %s, retrying in %ds: %s",
                        arn, retry_delay, e,
                    )
                    time.sleep(retry_delay)
                else:
                    logger.error("Failed to delete ECS service %s: %s", arn, e)
                    break

        try:
            waiter = client.get_waiter("services_inactive")
            logger.info("Waiting for ECS service to become inactive: %s", arn)
            waiter.wait(
                cluster=cluster_name,
                services=[service_name],
                WaiterConfig={"Delay": 10, "MaxAttempts": 18},
            )
        except WaiterError as e:
            logger.error("Timed out waiting for ECS service to become inactive %s: %s", arn, e)


def delete_load_balancers(arns: list[str]) -> None:
    """Delete ALBs and wait for deletion. Listeners are auto-deleted with the ALB."""
    client = boto3.client("elbv2", region_name=STATE_REGION)
    active_arns = []
    for arn in arns:
        try:
            client.modify_load_balancer_attributes(
                LoadBalancerArn=arn,
                Attributes=[{"Key": "deletion_protection.enabled", "Value": "false"}],
            )
        except ClientError as e:
            error_code = e.response.get("Error", {}).get("Code")
            if error_code != "LoadBalancerNotFound":
                logger.warning("Failed to disable deletion protection for %s: %s", arn, e)

        try:
            logger.info("Deleting load balancer: %s", arn)
            client.delete_load_balancer(LoadBalancerArn=arn)
            active_arns.append(arn)
        except ClientError as e:
            error_code = e.response.get("Error", {}).get("Code")
            if error_code == "LoadBalancerNotFound":
                logger.info("Load balancer %s already deleted", arn)
            else:
                logger.error("Failed to delete load balancer %s: %s", arn, e)

    if not active_arns:
        logger.info("All load balancers already deleted")
        return

    waiter = client.get_waiter("load_balancers_deleted")
    try:
        logger.info("Waiting for %d load balancer(s) to be deleted...", len(active_arns))
        waiter.wait(
            LoadBalancerArns=active_arns,
            WaiterConfig={"Delay": 15, "MaxAttempts": 20},
        )
        logger.info("All load balancers deleted")
    except WaiterError as e:
        logger.error("Timed out waiting for load balancer deletion: %s", e)


def delete_target_groups(arns: list[str]) -> None:
    """Delete target groups. Must be called after ALBs are deleted.

    Retries deletion if target group is still in use by a listener, as there can
    be a brief delay between ALB deletion and listener cleanup completing.
    """
    client = boto3.client("elbv2", region_name=STATE_REGION)
    max_retries = 5
    retry_delay = 10  # seconds

    for arn in arns:
        for attempt in range(max_retries):
            try:
                logger.info("Deleting target group: %s (attempt %d/%d)", arn, attempt + 1, max_retries)
                client.delete_target_group(TargetGroupArn=arn)
                logger.info("Target group deleted: %s", arn)
                break  # Success, exit retry loop
            except ClientError as e:
                error_code = e.response.get("Error", {}).get("Code")
                if error_code == "TargetGroupNotFound":
                    logger.info("Target group %s already deleted", arn)
                    break  # Already gone, success
                elif error_code == "ResourceInUse" and attempt < max_retries - 1:
                    logger.warning(
                        "Target group %s still in use (listener cleanup pending), "
                        "retrying in %ds... (attempt %d/%d)",
                        arn, retry_delay, attempt + 1, max_retries
                    )
                    time.sleep(retry_delay)
                else:
                    logger.error("Failed to delete target group %s: %s", arn, e)
                    break  # Give up after max retries or non-retryable error


def terminate_instances(arns: list[str]) -> None:
    """Terminate EC2 instances and wait for termination."""
    ec2 = boto3.client("ec2", region_name=STATE_REGION)
    instance_ids = [_extract_id_from_arn(arn) for arn in arns]

    # Filter out instances that no longer exist
    try:
        response = ec2.describe_instances(InstanceIds=instance_ids)
        existing_ids = []
        for reservation in response["Reservations"]:
            for instance in reservation["Instances"]:
                existing_ids.append(instance["InstanceId"])

        missing_ids = set(instance_ids) - set(existing_ids)
        if missing_ids:
            logger.info("Instances already deleted: %s", list(missing_ids))

        if not existing_ids:
            logger.info("All instances already terminated")
            return

        instance_ids = existing_ids
    except ClientError as e:
        error_code = e.response.get("Error", {}).get("Code")
        if error_code == "InvalidInstanceID.NotFound":
            logger.info("All instances already deleted")
            return
        logger.error("Failed to describe instances: %s", e)
        return

    try:
        logger.info("Terminating instances: %s", instance_ids)
        ec2.terminate_instances(InstanceIds=instance_ids)
    except ClientError as e:
        logger.error("Failed to terminate instances %s: %s", instance_ids, e)
        return

    waiter = ec2.get_waiter("instance_terminated")
    try:
        logger.info("Waiting for %d instance(s) to terminate...", len(instance_ids))
        waiter.wait(
            InstanceIds=instance_ids,
            WaiterConfig={"Delay": 15, "MaxAttempts": 40},
        )
        logger.info("All instances terminated")
    except WaiterError as e:
        logger.error("Timed out waiting for instance termination: %s", e)


def delete_nat_gateways(arns: list[str]) -> None:
    """Delete NAT Gateways and poll until deleted.

    No built-in waiter exists, so we poll describe_nat_gateways manually.
    """
    ec2 = boto3.client("ec2", region_name=STATE_REGION)
    nat_gw_ids = [_extract_id_from_arn(arn) for arn in arns]

    # Delete each NAT Gateway, skipping ones that don't exist
    active_nat_gw_ids = []
    for nat_gw_id in nat_gw_ids:
        try:
            logger.info("Deleting NAT gateway: %s", nat_gw_id)
            ec2.delete_nat_gateway(NatGatewayId=nat_gw_id)
            active_nat_gw_ids.append(nat_gw_id)
        except ClientError as e:
            error_code = e.response.get("Error", {}).get("Code")
            if error_code == "NatGatewayNotFound":
                logger.info("NAT gateway %s already deleted", nat_gw_id)
            else:
                logger.error("Failed to delete NAT gateway %s: %s", nat_gw_id, e)

    if not active_nat_gw_ids:
        logger.info("All NAT gateways already deleted")
        return

    # Poll for deletion status
    start_time = time.time()
    while time.time() - start_time < NAT_GW_POLL_TIMEOUT:
        try:
            response = ec2.describe_nat_gateways(NatGatewayIds=active_nat_gw_ids)
            states = {gw["NatGatewayId"]: gw["State"] for gw in response["NatGateways"]}
            logger.info("NAT Gateway states: %s", states)

            if all(state == "deleted" for state in states.values()):
                logger.info("All NAT gateways deleted")
                return
        except ClientError as e:
            error_code = e.response.get("Error", {}).get("Code")
            if error_code == "NatGatewayNotFound":
                # All NAT gateways are gone, which is the desired state
                logger.info("All NAT gateways confirmed deleted")
                return
            logger.error("Error checking NAT gateway status: %s", e)

        time.sleep(NAT_GW_POLL_INTERVAL)

    logger.error("Timed out waiting for NAT gateway deletion after %ds", NAT_GW_POLL_TIMEOUT)


def release_elastic_ips(arns: list[str]) -> None:
    """Release Elastic IPs. Must be called after NAT Gateways are fully deleted.

    Retries release if EIP is still associated (AuthFailure), as there can be
    a brief delay between NAT Gateway deletion and EIP disassociation completing.
    """
    ec2 = boto3.client("ec2", region_name=STATE_REGION)
    max_retries = 5
    retry_delay = 10  # seconds

    for arn in arns:
        allocation_id = _extract_id_from_arn(arn)
        for attempt in range(max_retries):
            try:
                logger.info("Releasing Elastic IP: %s (attempt %d/%d)", allocation_id, attempt + 1, max_retries)
                ec2.release_address(AllocationId=allocation_id)
                logger.info("Elastic IP released: %s", allocation_id)
                break  # Success, exit retry loop
            except ClientError as e:
                error_code = e.response.get("Error", {}).get("Code")
                if error_code == "InvalidAllocationID.NotFound":
                    logger.info("Elastic IP %s already released", allocation_id)
                    break  # Already gone, success
                elif error_code == "AuthFailure" and attempt < max_retries - 1:
                    logger.warning(
                        "Elastic IP %s still associated (NAT GW disassociation pending), "
                        "retrying in %ds... (attempt %d/%d)",
                        allocation_id, retry_delay, attempt + 1, max_retries
                    )
                    time.sleep(retry_delay)
                else:
                    logger.error("Failed to release Elastic IP %s: %s", allocation_id, e)
                    break  # Give up after max retries or non-retryable error


def lambda_handler(event, context):
    """Main handler. Checks state age and destroys expensive tagged resources."""
    logger.info("Destroyer invoked. TTL_MINUTES=%d", TTL_MINUTES)

    # Step 1: Check TTL via state file age
    age_minutes = get_state_age_minutes()
    if age_minutes is None:
        logger.info("No state file found -- nothing to destroy")
        return {"status": "skip", "reason": "no_state_file"}

    if age_minutes < TTL_MINUTES:
        logger.info(
            "State is %.1f minutes old, TTL is %d minutes -- not yet expired",
            age_minutes,
            TTL_MINUTES,
        )
        return {"status": "skip", "reason": "not_expired", "age_minutes": round(age_minutes, 1)}

    logger.info("TTL expired (%.1f minutes > %d minutes) -- discovering resources", age_minutes, TTL_MINUTES)

    # Step 2: Discover tagged resources
    resources = discover_tagged_resources()
    if not resources:
        logger.info("No resources tagged with %s=%s found", AUTO_DESTROY_TAG_KEY, AUTO_DESTROY_TAG_VALUE)
        return {"status": "skip", "reason": "no_tagged_resources", "age_minutes": round(age_minutes, 1)}

    # Step 3: Delete in dependency order
    deleted_types = []
    errors = []

    try:
        # 3a. Delete ECS services to stop Fargate tasks
        ecs_service_arns = resources.get("ecs:service", [])
        if ecs_service_arns:
            delete_ecs_services(ecs_service_arns)
            deleted_types.append("ecs_services")

        # 3b. Delete ALBs (listeners auto-deleted)
        alb_arns = resources.get("elasticloadbalancing:loadbalancer", [])
        if alb_arns:
            delete_load_balancers(alb_arns)
            deleted_types.append("load_balancers")

        # 3c. Delete target groups (must be after ALB deletion)
        tg_arns = resources.get("elasticloadbalancing:targetgroup", [])
        if tg_arns:
            delete_target_groups(tg_arns)
            deleted_types.append("target_groups")

        # 3d. Terminate EC2 instances
        instance_arns = resources.get("ec2:instance", [])
        if instance_arns:
            terminate_instances(instance_arns)
            deleted_types.append("instances")

        # 3e. Delete NAT Gateways (slow, 1-5 min)
        nat_arns = resources.get("ec2:natgateway", [])
        if nat_arns:
            delete_nat_gateways(nat_arns)
            deleted_types.append("nat_gateways")

        # 3f. Release Elastic IPs (must be after NAT GW fully deleted)
        eip_arns = resources.get("ec2:elastic-ip", [])
        if eip_arns:
            release_elastic_ips(eip_arns)
            deleted_types.append("elastic_ips")

    except Exception as e:
        logger.exception("Unexpected error during resource deletion")
        errors.append(str(e))

    result = {
        "status": "destroyed" if not errors else "partial",
        "age_minutes": round(age_minutes, 1),
        "deleted_types": deleted_types,
    }
    if errors:
        result["errors"] = errors

    logger.info("Destroy completed: %s", result)
    return result
