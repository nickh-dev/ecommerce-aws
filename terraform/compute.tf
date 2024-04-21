resource "aws_launch_template" "launch_template" {
  for_each               = toset(["blue", "green"])
  name                   = "launch_template_${each.key}"
  image_id               = data.aws_ami.ubuntu.id
  vpc_security_group_ids = [aws_security_group.ecommerce_sg.id]
  instance_type          = "t2.micro"
  key_name               = "key_pair"

  user_data = base64encode(<<EOF
#!/bin/bash

apt update && apt install -y docker.io mysql-client
systemctl start docker
systemctl enable docker

sleep 10

curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

mkdir -p /var/www/wordpress
cat > /var/www/wordpress/docker-compose.yml <<'EOF2'
version: '3.1'

services:
  wordpress:
    image: wordpress:latest
    ports:
      - "80:80"
    environment:
      WORDPRESS_DB_HOST: ${each.key == "blue" ? aws_db_instance.db_instance_blue.endpoint : aws_db_instance.db_instance_green.endpoint}
      WORDPRESS_DB_USER: ${each.key == "blue" ? aws_db_instance.db_instance_blue.username : aws_db_instance.db_instance_green.username}
      WORDPRESS_DB_PASSWORD: ${each.key == "blue" ? aws_db_instance.db_instance_blue.password : aws_db_instance.db_instance_green.password}
      WORDPRESS_DB_NAME: ${each.key == "blue" ? aws_db_instance.db_instance_blue.db_name : aws_db_instance.db_instance_green.db_name}
    volumes:
      - wordpress_data:/var/www/html
    restart: always

volumes:
  wordpress_data:
    driver: local
    
EOF2

cd /var/www/wordpress
docker-compose up -d
EOF
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "asg_blue" {
  name                = "blue_asg_group"
  vpc_zone_identifier = [for subnet in aws_subnet.public_subnet : subnet.id]
  desired_capacity    = 2
  max_size            = 3
  min_size            = 1
  target_group_arns   = [aws_lb_target_group.blue.arn]


  launch_template {
    id      = aws_launch_template.launch_template["blue"].id
    version = "$Latest"
  }
  tag {
    key                 = "Name"
    value               = "Blue Environment"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_group" "asg_green" {
  name                = "green_asg_group"
  vpc_zone_identifier = [for subnet in aws_subnet.public_subnet : subnet.id]
  desired_capacity    = 2
  max_size            = 3
  min_size            = 1
  target_group_arns   = [aws_lb_target_group.green.arn]


  launch_template {
    id      = aws_launch_template.launch_template["green"].id
    version = "$Latest"
  }
  tag {
    key                 = "Name"
    value               = "Green Environment"
    propagate_at_launch = true
  }
}
