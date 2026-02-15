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

  # Network CIDR blocks
  network_cidrs = {
    public_a  = cidrsubnet(var.vpc_cidr, 8, 1)  # 10.0.1.0/24
    public_b  = cidrsubnet(var.vpc_cidr, 8, 2)  # 10.0.2.0/24
    private_a = cidrsubnet(var.vpc_cidr, 8, 10) # 10.0.10.0/24
  }

  web_instance_html = <<-HTML
  <!DOCTYPE html>
  <html lang="en">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AWS Demo Environment</title>
    <style>
      body { font-family: system-ui, sans-serif; max-width: 600px; margin: 80px auto; padding: 0 20px; color: #333; }
      h1 { color: #232f3e; }
      .info { background: #f4f4f4; padding: 16px; border-radius: 8px; }
      .info dt { font-weight: bold; margin-top: 8px; }
    </style>
  </head>
  <body>
    <h1>AWS Demo Environment</h1>
    <p>This environment will be automatically destroyed after 24 hours.</p>
    <div class="info">
      <dl>
        <dt>Instance ID</dt><dd>{{INSTANCE_ID}}</dd>
        <dt>Availability Zone</dt><dd>{{AVAILABILITY_ZONE}}</dd>
      </dl>
    </div>
  </body>
  </html>
  HTML
}
