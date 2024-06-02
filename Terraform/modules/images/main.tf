# Crear el Bucket S3 para subir imagenes
resource "aws_s3_bucket" "image_bucket" {
  bucket_prefix = "image-bucket"
}

# Configurar la Política de Bucket S3
resource "aws_s3_bucket_public_access_block" "block_public_acls" {
  bucket = aws_s3_bucket.image_bucket.id

  block_public_policy     = false
  restrict_public_buckets = false
  block_public_acls       = true 
  ignore_public_acls      = true 
}

resource "aws_s3_bucket_policy" "image_bucket_policy" {
  bucket = aws_s3_bucket.image_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "PublicReadGetObject",
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.image_bucket.arn}/*"
      }
    ]
  })

  depends_on = [ aws_s3_bucket_public_access_block.block_public_acls ]
}

# Crear la fucnion lambda para procesar imagenes
resource "aws_lambda_function" "process_image_lambda" {
  filename      = "./process_image.zip"
  function_name = "process-image-lambda"
  role          = var.lambda_role_arn
  handler       = "process_image.lambda_handler"
  runtime       = "python3.8"

  environment {
    variables = {
      SQS_QUEUE_URL  = var.sqs_queue_url
    }
  }
}