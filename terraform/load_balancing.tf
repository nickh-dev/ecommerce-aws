resource "aws_lb" "main" {
  name               = "ALB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ecommerce_sg.id]
  subnets            = [for subnet in aws_subnet.public_subnet : subnet.id]
}

resource "aws_lb_target_group" "blue" {
  name     = "blue"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.ecommerce_vpc.id

  health_check {
    enabled             = true
    interval            = 30
    path                = "/"
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }
}

resource "aws_lb_target_group" "green" {
  name     = "green"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.ecommerce_vpc.id

  health_check {
    enabled             = true
    interval            = 30
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
    target_group_arn = aws_lb_target_group.green.arn
  }

  depends_on = [aws_lb_target_group.blue, aws_lb_target_group.green]
}
