# Crear el Bucket S3 para subir pedidos
resource "aws_s3_bucket" "orders_bucket" {
  bucket_prefix = "orders-bucket"
}

resource "aws_s3_bucket_public_access_block" "block_public_acls" {
  bucket = aws_s3_bucket.orders_bucket.id

  block_public_policy     = false
  restrict_public_buckets = false
  block_public_acls       = true 
  ignore_public_acls      = true 
}


# Configurar la Política de Bucket S3
resource "aws_s3_bucket_policy" "orders_bucket_policy" {
  bucket = aws_s3_bucket.orders_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "PublicReadGetObject",
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.orders_bucket.arn}/*"
      }
    ]
  })

  depends_on = [ aws_s3_bucket_public_access_block.block_public_acls ]
}

# Crear la función Lambda para procesar los pedidos
resource "aws_lambda_function" "process_orders_lambda" {
  filename      = "./process_orders.zip"
  function_name = "process-orders-lambda"
  role          = var.lambda_role_arn
  handler       = "process_orders.lambda_handler"
  runtime       = "python3.8"

  environment {
    variables = {
      SQS_QUEUE_URL  = var.sqs_queue_url
    }
  }
}