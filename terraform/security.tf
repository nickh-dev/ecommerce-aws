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
