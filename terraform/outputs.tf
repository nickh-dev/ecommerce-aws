output "dns_name" {
  description = "The DNS name of created ALB."
  value       = aws_lb.main.dns_name
}

output "blue_rds_endpoint" {
  description = "Blue RDS endpoint"
  value       = aws_db_instance.db_instance_blue.endpoint
}

output "green_rds_endpoint" {
  description = "Green RDS endpoint"
  value       = aws_db_instance.db_instance_green.endpoint
}

output "listener_arn" {
  description = "Listener's ARN"
  value       = aws_lb_listener.http.arn
}

output "blue_target_group_arn" {
  description = "Blue target group ARN"
  value       = aws_lb_target_group.blue.arn
}

output "green_target_group_arn" {
  description = "Green target group ARN"
  value       = aws_lb_target_group.green.arn
}
