resource "aws_lambda_function" "this" {
  function_name = var.function_name
  handler       = var.handler
  runtime       = var.runtime
  role          = var.role_arn
  s3_bucket     = var.s3_bucket
  s3_key        = var.s3_key

  environment {
    variables = var.environment_variables
  }

  tags = {
    Name = var.function_name
  }
}

output "lambda_function_name" {
  value = aws_lambda_function.this.function_name
}
