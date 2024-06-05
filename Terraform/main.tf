// Definir la región AWS
provider "aws" {
  region = "us-east-1"
}

# ------------------------------------------------------------------------------------------------------------------------------------------------

# Módulo para del rol IAM
module "iam_role" {
  source             = "./modules/iam_role"
  lambda_role_name   = "lambda_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# ------------------------------------------------------------------------------------------------------------------------------------------------

# Módulo para el sitio web estático
module "static_website" {
  source           = "./modules/static_website"
  lambda_role_arn  = module.iam_role.lambda_role.arn
}

# Crear la política de ejecución de Lambda para acceder a S3
resource "aws_iam_policy" "lambda_s3_policy" {
  name        = "lambda-s3-policy"
  description = "Policy for Lambda to access S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ],
        Resource = "${module.static_website.static_website.arn}/*"
      }
    ]
  })
}

# Adjuntar la política de permisos a la función Lambda para acceder a s3
resource "aws_iam_role_policy_attachment" "lambda_s3_attachment" {
  role       = module.iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_s3_policy.arn
}

# ------------------------------------------------------------------------------------------------------------------------------------------------

# Crear la cola SQS para el servicio de notificación/mensajería desacoplado
resource "aws_sqs_queue" "notification_queue" {
  name                       = "notification-queue"
  delay_seconds              = 0
  max_message_size           = 262144
  message_retention_seconds  = 345600
  visibility_timeout_seconds = 30
}

# Crear la política de permisos de Lambda para enviar mensajes a la cola SQS
resource "aws_iam_policy" "lambda_sqs_policy" {
  name        = "lambda-sqs-policy"
  description = "Policy for Lambda to access SQS"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl"
        ],
        Resource = "${aws_sqs_queue.notification_queue.arn}"
      }
    ]
  })
}

# Adjuntar la política de permisos a la función Lambda para enviar mensajes a la cola SQS
resource "aws_iam_role_policy_attachment" "lambda_sqs_attachment" {
  role       = module.iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_sqs_policy.arn
}

# ------------------------------------------------------------------------------------------------------------------------------------------------

# Módulo para bucket de pedidos
module "orders" {
  source          = "./modules/orders"
  lambda_role_arn = module.iam_role.lambda_role.arn
  sqs_queue_url   = aws_sqs_queue.notification_queue.url
}

# Crear un trigger S3 para invocar la función Lambda al subir un objeto
resource "aws_s3_bucket_notification" "orders_bucket_notification" {
  bucket = module.orders.orders_bucket.id

  lambda_function {
    lambda_function_arn = module.orders.process_orders_lambda.arn
    events        = ["s3:ObjectCreated:*"]
    filter_suffix = ".json"
  }

  depends_on = [aws_lambda_permission.s3_to_lambda_orders]
}

# Permiso para permitir que el bucket S3 invoque la función Lambda para procesar pedidos
resource "aws_lambda_permission" "s3_to_lambda_orders" {
  statement_id  = "AllowS3InvokeLambdaOrders"
  action        = "lambda:InvokeFunction"
  function_name = module.orders.process_orders_lambda.arn
  principal     = "s3.amazonaws.com"
  source_arn    = module.orders.orders_bucket.arn
}

# ------------------------------------------------------------------------------------------------------------------------------------------------

# Módulo para bucket de imágenes
module "images" {
  source          = "./modules/images"
  lambda_role_arn = module.iam_role.lambda_role.arn
  sqs_queue_url   = aws_sqs_queue.notification_queue.url
}

# Crear un trigger S3 para invocar la función Lambda al subir un objeto
resource "aws_s3_bucket_notification" "image_bucket_notification" {
  bucket = module.images.image_bucket.id

  lambda_function {
    lambda_function_arn = module.images.process_image_lambda.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.s3_to_lambda_image]
}

# Permiso para permitir que el bucket S3 invoque la función Lambda para procesar imágenes
resource "aws_lambda_permission" "s3_to_lambda_image" {
  statement_id  = "AllowS3InvokeLambdaImage"
  action        = "lambda:InvokeFunction"
  function_name = module.images.process_image_lambda.arn
  principal     = "s3.amazonaws.com"
  source_arn    = module.images.image_bucket.arn
}

# ------------------------------------------------------------------------------------------------------------------------------------------------

# Módulo para el logging
module "logging" {
  source                              = "./modules/logging"
  static_lambda_function_name         = module.static_website.static_site_lambda.function_name
  process_image_lambda_function_name  = module.images.process_image_lambda.function_name
  process_orders_lambda_function_name = module.orders.process_orders_lambda.function_name
}
