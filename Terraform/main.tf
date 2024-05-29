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

# Crear el Bucket S3
resource "aws_s3_bucket" "static_website" {
  bucket_prefix = "static-website"
}

# Subir archivos HTML estáticos al Bucket S3
resource "aws_s3_object" "index_html" {
  bucket = aws_s3_bucket.static_website.id
  key    = "index.html"
  source = "../index.html"  # Ruta local del archivo HTML estático
}

# Crear la Función Lambda
resource "aws_lambda_function" "static_site_lambda" {
  filename      = "./lambda_function.zip"
  function_name = "static-site-lambda"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "nodejs14.x"
}

# Crear el rol IAM para la ejecución de la función Lambda
resource "aws_iam_role" "lambda_role" {
  name               = "lambda_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_role_assume.json
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
data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "s3_lambda_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${aws_s3_bucket.static_website.id}/*"]

    principals {
      type        = "AWS"
      identifiers = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_s3_bucket_policy" "lambda_access_policy" {
  bucket = aws_s3_bucket.static_website.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = [
          "s3:GetObject"
        ],
        Resource = [
          "${aws_s3_bucket.static_website.arn}/*"
        ]
      }
    ]
  })
}

# Crear un API Gateway
resource "aws_api_gateway_rest_api" "static_site_api" {
  name = "static-site-api"
}

resource "aws_api_gateway_resource" "site" {
  rest_api_id = aws_api_gateway_rest_api.static_site_api.id
  parent_id   = aws_api_gateway_rest_api.static_site_api.root_resource_id
  path_part   = "site"
}

resource "aws_api_gateway_method" "get" {
  rest_api_id   = aws_api_gateway_rest_api.static_site_api.id
  resource_id   = aws_api_gateway_resource.site.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id = aws_api_gateway_rest_api.static_site_api.id
  resource_id = aws_api_gateway_resource.site.id
  http_method = aws_api_gateway_method.get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.static_site_lambda.invoke_arn
}

# Permiso para que API Gateway invoque la función Lambda
resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.static_site_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.static_site_api.execution_arn}/*"
}

data "aws_region" "current" {}

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

# Crear un recurso de rol IAM para la ejecución de la función Lambda
resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Adjuntar la política básica de ejecución de Lambda al rol
resource "aws_iam_policy_attachment" "lambda_policy" {
  name       = "lambda_policy_attach"
  roles      = [aws_iam_role.lambda_exec.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Crear la política de ejecución de Lambda
data "aws_iam_policy_document" "lambda_policy" {
  statement {
    actions = ["lambda:InvokeFunction"]
    resources = [aws_lambda_function.static_site_lambda.arn]
  }
}

# Crear el permiso para invocar la función Lambda
resource "aws_lambda_permission" "invoke_lambda" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.static_site_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = aws_api_gateway_rest_api.static_site_api.execution_arn
}

# Probar el Sitio Institucional
output "site_url" {
  value = "https://${aws_api_gateway_rest_api.static_site_api.id}.execute-api.${data.aws_region.current.name}.amazonaws.com"
}
