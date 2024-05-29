resource "tls_private_key" "key_gen" {  
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_s3_object" "private_key" {  
  bucket  = var.ssh_bucket
  key     = "${var.instance_name}.pem"
  content = tls_private_key.key_gen.private_key_openssh
}

resource "aws_key_pair" "key" {  
  key_name   = "${var.instance_name}-key"
  public_key = tls_private_key.key_gen.public_key_openssh
}

resource "aws_instance" "ec2" {
  count = var.instance_count

  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = aws_key_pair.key.key_name
  subnet_id = var.subnet_id
  ipv6_address_count = var.enable_ipv6 ? 1 : 0

  vpc_security_group_ids = [aws_security_group.sg.id] 
  

  tags = {
    Name = "${var.instance_name}"
  }
} 

resource "aws_security_group" "sg" {
  name = "${var.instance_name}-sg"
  vpc_id = var.vpc_id
  description = "Managed by Terraform"
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  dynamic "ingress" {
    for_each = var.security_group_rules.ingress
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
      ipv6_cidr_blocks = ingress.value.ipv6_cidr_blocks
    }
    
  }

  dynamic "egress" {
    for_each = var.security_group_rules.egress
    content {
      from_port   = egress.value.from_port
      to_port     = egress.value.to_port
      protocol    = egress.value.protocol
      cidr_blocks = egress.value.cidr_blocks
      ipv6_cidr_blocks = egress.value.ipv6_cidr_blocks
    }
  }  
  lifecycle {
    ignore_changes = [
      # Ignore changes in ingress rules
      ingress,
    ]
  }
} 
