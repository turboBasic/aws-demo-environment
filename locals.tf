locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
    TTL         = "24h"
  }

  auto_destroy_tags = {
    AutoDestroy = "true"
  }

  vpc_cidr       = var.vpc_cidr
  public_a_cidr  = "10.0.1.0/24"
  public_b_cidr  = "10.0.2.0/24"
  private_a_cidr = "10.0.10.0/24"
}
