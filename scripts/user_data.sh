#!/bin/bash
set -euo pipefail

dnf install -y httpd
systemctl enable httpd
systemctl start httpd

INSTANCE_ID=$(ec2-metadata -i | cut -d' ' -f2)
AZ=$(ec2-metadata -z | cut -d' ' -f2)

cat > /var/www/html/index.html <<'HTML'
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
HTML

cat >> /var/www/html/index.html <<DYNAMIC
      <dt>Instance ID</dt><dd>${INSTANCE_ID}</dd>
      <dt>Availability Zone</dt><dd>${AZ}</dd>
DYNAMIC

cat >> /var/www/html/index.html <<'HTML'
    </dl>
  </div>
</body>
</html>
HTML
