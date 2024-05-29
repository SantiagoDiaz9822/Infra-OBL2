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

module "s3" {
  source         = "./modules/s3"
  bucket_name    = "obl-s3-2024"
  force_destroy  = true
}

resource "aws_s3_object" "object" {
  bucket = module.s3.bucket
  key    = "index.html"
  source = "../index.html"
}

resource "aws_s3_object" "lambda_zip" {
  bucket = module.s3.bucket
  key    = "lambda_function.zip"
  source = "./lambda_function.zip"
}

module "ec2" {
  for_each = { for vm in local.EC2_INSTANCES : vm.instance_name => vm }
  source   = "./modules/ec2"

  subnet_id            = each.value.public ? data.aws_subnets.Public-subnets.ids[0] : data.aws_subnets.Private-subnets.ids[0]
  ami_id               = each.value.ami_id
  instance_type        = each.value.instance_type
  instance_name        = each.value.instance_name
  instance_count       = each.value.instance_count
  ssh_bucket           = module.s3.bucket
  enable_ipv6          = each.value.enable_ipv6
  vpc_id               = data.aws_vpc.VPC1.id
  security_group_rules = each.value.security_group_rules
}

module "lambda" {
  source            = "./modules/lambda"
  function_name     = "my_lambda_function"
  handler           = "lambda_function.lambda_handler"
  runtime           = "python3.8"
  s3_bucket         = module.s3.bucket
  s3_key            = "lambda_function.zip"
  role_arn          = aws_iam_role.lambda_exec.arn
}

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