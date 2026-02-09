"""Lambda handler that checks Terraform state age and destroys expired demo environments."""

import json
import logging
import os
import subprocess
import tempfile
from datetime import datetime, timezone

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Environment variables
GITHUB_REPO = os.environ["GITHUB_REPO"]
SECRET_ARN = os.environ["SECRET_ARN"]
STATE_BUCKET = os.environ["STATE_BUCKET"]
STATE_KEY = os.environ["STATE_KEY"]
STATE_REGION = os.environ["STATE_REGION"]
DYNAMODB_TABLE = os.environ["DYNAMODB_TABLE"]
TTL_HOURS = int(os.environ["TTL_HOURS"])


def get_github_token() -> str:
    """Retrieve GitHub token from Secrets Manager."""
    client = boto3.client("secretsmanager", region_name=STATE_REGION)
    response = client.get_secret_value(SecretId=SECRET_ARN)
    return response["SecretString"]


def get_state_age_hours() -> float | None:
    """Check the age of the Terraform state file in S3. Returns None if no state exists."""
    s3 = boto3.client("s3", region_name=STATE_REGION)
    try:
        response = s3.head_object(Bucket=STATE_BUCKET, Key=STATE_KEY)
    except s3.exceptions.ClientError as e:
        if e.response["Error"]["Code"] == "404":
            logger.info("No state file found at s3://%s/%s", STATE_BUCKET, STATE_KEY)
            return None
        raise

    last_modified = response["LastModified"]
    age = datetime.now(timezone.utc) - last_modified
    age_hours = age.total_seconds() / 3600
    logger.info(
        "State file last modified: %s (%.1f hours ago)", last_modified.isoformat(), age_hours
    )
    return age_hours


def state_has_resources() -> bool:
    """Check if the Terraform state file contains any managed resources."""
    s3 = boto3.client("s3", region_name=STATE_REGION)
    try:
        response = s3.get_object(Bucket=STATE_BUCKET, Key=STATE_KEY)
        state = json.loads(response["Body"].read())
    except Exception:
        logger.exception("Failed to read state file")
        return False

    resources = state.get("resources", [])
    managed = [r for r in resources if r.get("mode") == "managed"]
    logger.info("State contains %d managed resources", len(managed))
    return len(managed) > 0


def run_terraform_destroy(work_dir: str) -> None:
    """Run terraform init and destroy in the given directory."""
    backend_config = [
        f"-backend-config=bucket={STATE_BUCKET}",
        f"-backend-config=key={STATE_KEY}",
        f"-backend-config=region={STATE_REGION}",
        f"-backend-config=dynamodb_table={DYNAMODB_TABLE}",
        "-backend-config=encrypt=true",
    ]

    # terraform init
    init_cmd = ["terraform", "init", "-input=false"] + backend_config
    logger.info("Running: %s", " ".join(init_cmd))
    result = subprocess.run(init_cmd, cwd=work_dir, capture_output=True, text=True, timeout=300)
    logger.info("Init stdout: %s", result.stdout)
    if result.returncode != 0:
        logger.error("Init stderr: %s", result.stderr)
        raise RuntimeError(f"terraform init failed with exit code {result.returncode}")

    # terraform destroy
    destroy_cmd = ["terraform", "destroy", "-auto-approve", "-input=false"]
    logger.info("Running: %s", " ".join(destroy_cmd))
    result = subprocess.run(
        destroy_cmd, cwd=work_dir, capture_output=True, text=True, timeout=600
    )
    logger.info("Destroy stdout: %s", result.stdout)
    if result.returncode != 0:
        logger.error("Destroy stderr: %s", result.stderr)
        raise RuntimeError(f"terraform destroy failed with exit code {result.returncode}")

    logger.info("Terraform destroy completed successfully")


def lambda_handler(event, context):
    """Main Lambda handler. Checks state age and destroys if TTL exceeded."""
    logger.info("Destroyer invoked. TTL_HOURS=%d", TTL_HOURS)

    age_hours = get_state_age_hours()
    if age_hours is None:
        logger.info("No state file found — nothing to destroy")
        return {"status": "skip", "reason": "no_state_file"}

    if age_hours < TTL_HOURS:
        logger.info("State is %.1f hours old, TTL is %d hours — not yet expired", age_hours, TTL_HOURS)
        return {"status": "skip", "reason": "not_expired", "age_hours": age_hours}

    if not state_has_resources():
        logger.info("State file exists but has no managed resources — nothing to destroy")
        return {"status": "skip", "reason": "no_resources"}

    logger.info("State is %.1f hours old (TTL=%d) — proceeding with destroy", age_hours, TTL_HOURS)

    # Clone the repository
    token = get_github_token()
    repo_url = GITHUB_REPO.replace("https://", f"https://x-access-token:{token}@")

    with tempfile.TemporaryDirectory() as tmp_dir:
        logger.info("Cloning repository into %s", tmp_dir)
        subprocess.run(
            ["git", "clone", "--depth", "1", repo_url, tmp_dir],
            capture_output=True,
            text=True,
            check=True,
            timeout=120,
        )

        # Uncomment backend config for init
        run_terraform_destroy(tmp_dir)

    return {"status": "destroyed", "age_hours": age_hours}
