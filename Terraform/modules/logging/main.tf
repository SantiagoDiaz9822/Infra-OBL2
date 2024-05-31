resource "aws_cloudwatch_log_group" "static_site_lambda_log_group" {
  name             = "/aws/lambda/${var.static_lambda_function_name}"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "process_image_lambda_log_group" {
  name             = "/aws/lambda/${var.process_image_lambda_function_name}"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "process_orders_lambda_log_group" {
  name             = "/aws/lambda/${var.process_orders_lambda_function_name}"
  retention_in_days = 14
}
