# Locales
locals {
  VPC1ID = "vpc-0ccc796febac1affa"

  EC2_INSTANCES = [
    {
      ami_id = "ami-051f8a213df8bc089",
      instance_type = "t2.micro",
      instance_name = "Public instance",
      instance_count = 1,
      public = true,
      enable_ipv6 = true,
      security_group_rules = {
        ingress = [
          {
            from_port         = 22,
            to_port           = 22,
            protocol          = "tcp",
            cidr_blocks       = ["0.0.0.0/0"],
            ipv6_cidr_blocks  = ["::/0"]
          },
          {
            from_port         = 80,
            to_port           = 80,
            protocol          = "tcp",
            cidr_blocks       = ["0.0.0.0/0"],
            ipv6_cidr_blocks  = ["::/0"]
          }
        ],
        egress = [
          {
            from_port         = 0,
            to_port           = 0,
            protocol          = "-1",
            cidr_blocks       = ["0.0.0.0/0"],
            ipv6_cidr_blocks  = ["::/0"]
          }
        ]
      }
    },
    {
      ami_id = "ami-058bd2d568351da34",
      instance_type = "t2.micro",
      instance_name = "Private instance",
      instance_count = 1,
      public = false,
      enable_ipv6 = false,
      security_group_rules = {
        ingress = [
          {
            from_port         = 22,
            to_port           = 22,
            protocol          = "tcp",
            cidr_blocks       = ["0.0.0.0/0"],
            ipv6_cidr_blocks  = ["::/0"]
          }
        ],
        egress = [
          {
            from_port         = 0,
            to_port           = 0,
            protocol          = "-1",
            cidr_blocks       = ["0.0.0.0/0"],
            ipv6_cidr_blocks  = ["::/0"]
          }
        ]
      }
    }
  ]
}

# Recuperar información de la VPC y subredes
data "aws_vpc" "VPC1" {
  id = local.VPC1ID
}
data "aws_subnets" "Private-subnets" {
  filter {
    name   = "tag:Name"
    values = ["subnet-private-1*"]
  }
}

data "aws_subnets" "Public-subnets" {
  filter {
    name   = "tag:Name"
    values = ["subnet-public-1*"]
  }
}

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

# Crear la Función Lambda para servir el Sitio Estático
resource "aws_lambda_function" "static_site_lambda" {
  filename      = "./lambda_function.zip"
  function_name = "static-site-lambda"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.8"

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.static_website.bucket
    }
  }
}

# Crear el rol IAM para la ejecución de la función Lambda 
resource "aws_iam_role" "lambda_role" {
  name               = "lambda_role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action    = "sts:AssumeRole"
      }
    ]
  })
  
}

# Documento de política para permitir a Lambda asumir el rol
data "aws_iam_policy_document" "lambda_role_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# Configurar la Política de Bucket S3
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
}

# Crear un API Gateway HTTP no REST
resource "aws_apigatewayv2_api" "static_site_api" {
  name          = "static-site-api"
  protocol_type = "HTTP"
}

# Crear las instancias EC2
module "ec2" {
  for_each = { for vm in local.EC2_INSTANCES : vm.instance_name => vm }
  source   = "./modules/ec2"

  subnet_id            = each.value.public ? data.aws_subnets.Public-subnets.ids[0] : data.aws_subnets.Private-subnets.ids[0]
  ami_id               = each.value.ami_id
  instance_type        = each.value.instance_type
  instance_name        = each.value.instance_name
  instance_count       = each.value.instance_count
  ssh_bucket           = aws_s3_bucket.static_website.id
  enable_ipv6          = each.value.enable_ipv6
  vpc_id               = data.aws_vpc.VPC1.id
  security_group_rules = each.value.security_group_rules
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

# Crear un recurso de permiso para permitir a API Gateway invocar la función Lambda
resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.static_site_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.static_site_api.execution_arn}/*"
}

# Crear un despliegue de la API
data "aws_region" "current" {}

# Crear un recurso de rol IAM para la ejecución de la función Lambda
resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version   ="2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

# Adjuntar la política básica de ejecución de Lambda al rol
resource "aws_iam_policy_attachment" "lambda_policy" {
  name       = "lambda_policy_attach"
  roles      = [aws_iam_role.lambda_exec.name]
  policy_arn = aws_iam_policy.lambda_s3_policy.arn  # Cambiamos al ARN de la política de S3
}

# Crear la política de ejecución de Lambda
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
        Resource = "${aws_s3_bucket.static_website.arn}/*"
      }
    ]
  })
}

data "aws_iam_policy_document" "lambda_policy" {
  statement {
    actions   = ["lambda:InvokeFunction"]
    resources = [aws_lambda_function.static_site_lambda.arn]
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

# Probar el Sitio Institucional
output "site_url" {
  value = "${aws_apigatewayv2_api.static_site_api.api_endpoint}/site"
}


# Crear una cola SQS para el servicio de notificación/mensajería desacoplado
resource "aws_sqs_queue" "notification_queue" {
  name                      = "notification-queue"
  delay_seconds             = 0
  max_message_size          = 262144
  message_retention_seconds = 345600
  visibility_timeout_seconds = 30
}

# Crear el Bucket S3 para subir pedidos
resource "aws_s3_bucket" "orders_bucket" {
  bucket_prefix = "orders-bucket"
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
}

# Crear una función Lambda para procesar los pedidos desde S3
resource "aws_lambda_function" "process_orders_lambda" {
  filename      = "./process_orders.zip"
  function_name = "process-orders-lambda"
  role          = aws_iam_role.lambda_role.arn
  handler       = "process_orders.lambda_handler"
  runtime       = "python3.8"

  environment {
    variables = {
      S3_BUCKET_NAME = aws_s3_bucket.orders_bucket.bucket
    }
  }
}

# Configurar la política de permisos para la función Lambda
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
          "sqs:DeleteMessage"
        ],
        Resource = "${aws_sqs_queue.notification_queue.arn}/*"
      }
    ]
  })
}

# Adjuntar la política de permisos a la función Lambda
resource "aws_iam_role_policy_attachment" "lambda_sqs_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_sqs_policy.arn
}
