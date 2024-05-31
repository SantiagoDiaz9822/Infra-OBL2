output "static_site_lambda_log_group_name" {
  value = aws_cloudwatch_log_group.static_site_lambda_log_group.name
}

output "process_image_lambda_log_group_name" {
  value = aws_cloudwatch_log_group.process_image_lambda_log_group.name
}

output "process_orders_lambda_log_group_name" {
  value = aws_cloudwatch_log_group.process_orders_lambda_log_group.name
}
