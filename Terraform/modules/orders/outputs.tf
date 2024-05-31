output "orders_bucket" {
  value = aws_s3_bucket.orders_bucket
}

output "process_orders_lambda" {
  value = aws_lambda_function.process_orders_lambda
}