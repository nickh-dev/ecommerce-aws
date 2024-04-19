#!/bin/bash

sudo apt update
sudo apt install nginx -y

# Get the instance metadata
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
INSTANCE_PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

# Create a custom HTML page with instance details

cat << EOF | sudo tee /var/www/html/index.html
<!DOCTYPE html>
<html>
<head>
    <title>Check High Availability</title>
</head>
<body>
    <h1>Hello from Instance $INSTANCE_ID</h1>
    <p>Public IP: $INSTANCE_PUBLIC_IP</p>
</body>
</html>
EOF


systemctl start nginx
systemctl enable --now nginx