resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "db_subnet_group"
  subnet_ids = [for subnet in aws_subnet.private_subnet : subnet.id]

  tags = {
    Name = "SqlSubnetGroup"
  }
}

resource "aws_db_instance" "db_instance_blue" {
  identifier           = "wordpress-rds-blue"
  instance_class       = "db.t3.micro"
  engine               = "mysql"
  engine_version       = "8.0.35"
  db_name              = "wordpress_blue"
  username             = "admin"
  password             = "password123"
  db_subnet_group_name = aws_db_subnet_group.db_subnet_group.name
  allocated_storage    = 20

  vpc_security_group_ids = [aws_security_group.ecommerce_sg.id]

  publicly_accessible = true
  skip_final_snapshot = true

  tags = {
    Name = "DevelopmentBlue"
  }
}

resource "aws_db_instance" "db_instance_green" {
  identifier           = "wordpress-rds-green"
  instance_class       = "db.t3.micro"
  engine               = "mysql"
  engine_version       = "8.0.35"
  db_name              = "wordpress_green"
  username             = "admin"
  password             = "password123"
  db_subnet_group_name = aws_db_subnet_group.db_subnet_group.name
  allocated_storage    = 20

  vpc_security_group_ids = [aws_security_group.ecommerce_sg.id]

  publicly_accessible = true
  skip_final_snapshot = true

  tags = {
    Name = "DevelopmentGreen"
  }
}
