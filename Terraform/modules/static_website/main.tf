# Crear el Bucket S3 para el Sitio Estático
resource "aws_s3_bucket" "static_website" {
  bucket_prefix = "static-website"
}

# Subir archivos HTML estáticos al Bucket S3 
resource "aws_s3_object" "index_html" {
  bucket = aws_s3_bucket.static_website.id
  key    = "index.html"
  source = "../index.html"  # Ruta local del archivo HTML estático
}

# Configurar la Política de Bucket S3
resource "aws_s3_bucket_public_access_block" "block_public_acls" {
  bucket = aws_s3_bucket.static_website.id

  block_public_policy     = false
  restrict_public_buckets = false
  block_public_acls       = true 
  ignore_public_acls      = true 
}

resource "aws_s3_bucket_policy" "lambda_access_policy" {
  bucket = aws_s3_bucket.static_website.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "PublicReadGetObject",
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.static_website.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.block_public_acls]
}

# Crear un API Gateway HTTP no REST
resource "aws_apigatewayv2_api" "static_site_api" {
  name          = "static-site-api"
  protocol_type = "HTTP"
}

# Crear una integración con la función Lambda
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                    = aws_apigatewayv2_api.static_site_api.id
  integration_type          = "AWS_PROXY"
  integration_method        = "POST"
  integration_uri           = aws_lambda_function.static_site_lambda.invoke_arn
}

# Crear una ruta predeterminada para la API
resource "aws_apigatewayv2_route" "api_route" {
  api_id    = aws_apigatewayv2_api.static_site_api.id
  route_key = "$default"

  target = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# Crear un despliegue de la API
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.static_site_api.id
  name        = "$default"
  auto_deploy = true
}

# Crear la Función Lambda para servir el Sitio Estático
resource "aws_lambda_function" "static_site_lambda" {
  filename      = "./static-site-lambda.zip"
  function_name = "static-site-lambda"
  role          = var.lambda_role_arn
  handler       = "static-site-lambda.lambda_handler"
  runtime       = "python3.8"

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.static_website.bucket
    }
  }
}

# Crear el permiso para invocar la función Lambda
resource "aws_lambda_permission" "invoke_lambda" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.static_site_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.static_site_api.execution_arn}/*"
}
