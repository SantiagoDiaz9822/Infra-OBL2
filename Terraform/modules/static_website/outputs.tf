output "site_url" {
  value = "${aws_apigatewayv2_api.static_site_api.api_endpoint}/site"
}

output "static_website" {
  value = aws_s3_bucket.static_website
}

output "static_site_lambda" {
  value = aws_lambda_function.static_site_lambda 
}