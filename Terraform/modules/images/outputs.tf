output "image_bucket" {
  value = aws_s3_bucket.image_bucket
}

output "process_image_lambda" {
  value = aws_lambda_function.process_image_lambda
}