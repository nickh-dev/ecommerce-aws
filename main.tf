terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0.0"
    }
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"]
}

resource "aws_vpc" "ecommerce_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "EcommerceVPC"
  }
}

resource "aws_subnet" "public_subnet" {
  count                   = 3
  vpc_id                  = aws_vpc.ecommerce_vpc.id
  cidr_block              = cidrsubnet("10.0.0.0/16", 8, count.index)
  map_public_ip_on_launch = true
  availability_zone       = element(["eu-central-1a", "eu-central-1b", "eu-central-1c"], count.index)
  tags = {
    Name = "PublicSubnet-${count.index + 1}"
  }
}

resource "aws_subnet" "private_subnet" {
  count                   = 3
  vpc_id                  = aws_vpc.ecommerce_vpc.id
  cidr_block              = cidrsubnet("10.0.0.0/16", 8, count.index + 3)
  map_public_ip_on_launch = false
  availability_zone       = element(["eu-central-1a", "eu-central-1b", "eu-central-1c"], count.index)
  tags = {
    Name = "PrivateSubnet-${count.index + 1}"
  }
}

resource "aws_internet_gateway" "new_igw" {
  vpc_id = aws_vpc.ecommerce_vpc.id
  tags = {
    Name = "InternetGateway"
  }

}
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.ecommerce_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.new_igw.id
  }

  tags = {
    Name = "PublicRouteTable"
  }
}

resource "aws_route_table_association" "public_rta" {
  count          = 3
  subnet_id      = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_security_group" "ecommerce_sg" {
  name   = "ecommerce_security_group"
  vpc_id = aws_vpc.ecommerce_vpc.id

  dynamic "ingress" {
    for_each = ["80", "22", "3306"]
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "MySecurityGroup"
  }
}

resource "aws_launch_template" "new_launch_template" {
  image_id               = data.aws_ami.ubuntu.id
  vpc_security_group_ids = [aws_security_group.ecommerce_sg.id]
  instance_type          = "t2.micro"
  key_name               = "key_pair"
  user_data              = filebase64("script.sh")

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb" "main" {
  name               = "NewALB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ecommerce_sg.id]
  subnets            = [for subnet in aws_subnet.public_subnet : subnet.id]
}

resource "aws_lb_target_group" "blue" {
  name     = "BlueTargetGroup"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.ecommerce_vpc.id

  health_check {
    enabled             = true
    interval            = 45
    path                = "/"
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }
}

resource "aws_lb_target_group" "green" {
  name     = "GreenTargetGroup"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.ecommerce_vpc.id

  health_check {
    enabled             = true
    interval            = 45
    path                = "/"
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blue.arn
  }
}

resource "aws_autoscaling_group" "ecommerce_asg" {
  name                = "new_autoscaling_group"
  vpc_zone_identifier = [for subnet in aws_subnet.public_subnet : subnet.id]
  desired_capacity    = 2
  max_size            = 3
  min_size            = 1
  target_group_arns   = [aws_lb_target_group.blue.arn]

  launch_template {
    id      = aws_launch_template.new_launch_template.id
    version = "$Latest"
  }
}

resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "mysql_subnet_group"
  subnet_ids = [for subnet in aws_subnet.private_subnet : subnet.id]

  tags = {
    Name = "SqlSubnetGroup"
  }
}

resource "aws_db_instance" "db_instance" {
  identifier           = "sqldb"
  instance_class       = "db.t3.micro"
  engine               = "mysql"
  engine_version       = "8.0.35"
  username             = "admin"
  password             = "password123"
  db_subnet_group_name = aws_db_subnet_group.db_subnet_group.name
  allocated_storage    = 20

  vpc_security_group_ids = [aws_security_group.ecommerce_sg.id]

  publicly_accessible = true
  skip_final_snapshot = true

  tags = {
    Name = "Development"
  }
}

resource "aws_ecr_repository" "ecommerce_website" {
  name                 = "ecommerce-website"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecs_cluster" "ecommerce_cluster" {
  name = "ecommerce_cluster"
}

resource "aws_ecs_task_definition" "ecommerce_task" {
  family                   = "ecommerce_task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([
    {
      name      = "ecommerce_web",
      image     = "${aws_ecr_repository.ecommerce_website.repository_url}:latest",
      cpu       = 256,
      memory    = 512,
      essential = true,
      portMappings = [
        {
          containerPort = 80,
          hostPort      = 80,
          protocol      = "tcp"
        }
      ]
    }
  ])

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
}

resource "aws_ecs_service" "ecommerce_service" {
  name            = "ecommerce_service"
  cluster         = aws_ecs_cluster.ecommerce_cluster.id
  task_definition = aws_ecs_task_definition.ecommerce_task.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [for subnet in aws_subnet.private_subnet : subnet.id]
    security_groups  = [aws_security_group.ecommerce_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.blue.arn
    container_name   = "ecommerce_web"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.http]
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs_task_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Effect = "Allow"
        Sid    = ""
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
