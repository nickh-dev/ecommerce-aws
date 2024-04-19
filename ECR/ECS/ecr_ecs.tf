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
