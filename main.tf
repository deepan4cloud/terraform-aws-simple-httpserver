## Terraform Plugin Required Provider Version ##

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

## Remote Backend Configuration - Using S3 as Remote Backend ##

terraform {
  backend "s3" {
    bucket = "tfbackendforss"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}

## Local Backend ## -> Enable below block if you dont want to use above remote backend ## 

# terraform {
#   backend "local" {
#     path = "./terraform.tfstate"
#   }
# }

## Terraform Provider ##

provider "aws" {
  region = var.region
}

## Using existing VPC - default VPC ##

data "aws_vpc" "default" {}

## Using existing subnets - default Subnets ##

resource "aws_default_subnet" "pub_subnet-" {
  count                   = length(var.availability_zones)
  availability_zone       = element(var.availability_zones, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "Subnet-${count.index + 1}"
  }
}

## Creating a new Security Group for LoadBalancer ##

resource "aws_security_group" "alb-sg" {
  name        = "alb-sg"
  description = "Allow http inbound traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = var.http_port
    to_port     = var.http_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

## Creating a new Security Group for EC2 Instances ##

resource "aws_security_group" "webserver-sg" {
  name        = "ec2-sg"
  description = "ec2 sg to allow traffic from ALB SG & SSH only from my IP"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port       = var.http_port
    to_port         = var.http_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb-sg.id]
  }

  ingress {
    from_port   = var.ssh_port
    to_port     = var.ssh_port
    protocol    = "tcp"
    cidr_blocks = var.myip
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

## Creating Application LoadBalancer - ALB ##

resource "aws_alb" "ss-alb" {
  name            = "ss-alb"
  subnets         = aws_default_subnet.pub_subnet-.*.id
  security_groups = [aws_security_group.alb-sg.id]

  tags = {
    Name = "Application Loadbalancer for SS"
  }
}

## Creating Application LoadBalancer Listener ##

resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = aws_alb.ss-alb.arn
  port              = var.http_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb-web-tg.arn
  }
}

## Creating Application LoadBalancer Target Group ##

resource "aws_lb_target_group" "alb-web-tg" {
  name     = "ss-alb-tg"
  port     = var.http_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id
  stickiness {
    type            = "lb_cookie"
    cookie_duration = 1800
    enabled         = true
  }
  health_check {
    enabled             = true
    interval            = 30 # 300
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5     # 120
    healthy_threshold   = 5     # 2
    unhealthy_threshold = 2     # 2
    matcher             = "200" # "200"
  }
  tags = {
    Name = "ss-alb-tg"
  }
}

## Attaching TG with ALB ##

resource "aws_lb_target_group_attachment" "alb-web-tg-attachment" {
  target_group_arn = aws_lb_target_group.alb-web-tg.arn
  count            = length(var.availability_zones)
  target_id        = element(aws_instance.ss-instance-.*.id, count.index)
  port             = var.http_port
}

## Fetching Latest Amazon Linux AMI id##

data "aws_ami" "aws-linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn-ami-hvm*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

## Creating EC2 Instances in each AZ based on counts ##

resource "aws_instance" "ss-instance-" {
  ami                         = data.aws_ami.aws-linux.id
  associate_public_ip_address = true
  count                       = length(var.availability_zones)
  instance_type               = var.instance_type
  subnet_id                   = element(aws_default_subnet.pub_subnet-.*.id, count.index)
  key_name                    = var.generated_key_pair
  vpc_security_group_ids      = [aws_security_group.webserver-sg.id]
  depends_on = [
    aws_key_pair.ss_key_pair
  ]
  user_data = data.cloudinit_config.web.rendered

  tags = {
    Name = "ss-instance-${count.index}"
  }
}

## Creating new key pair for EC2 Instances & Copy the PEM file locally to use ##

resource "tls_private_key" "sskey" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ss_key_pair" {
  key_name   = var.generated_key_pair
  public_key = tls_private_key.sskey.public_key_openssh

  provisioner "local-exec" {
    command = "echo '${tls_private_key.sskey.private_key_pem}' > ./'${var.generated_key_pair}'.pem"
  }

  provisioner "local-exec" {
    command = "chmod 400 ./'${var.generated_key_pair}'.pem"
  }
}

## Setting User_data - Copying webserver.py to EC2 Instances & Running the Python Simple HTTPServer ##

locals {
  cloud_config_config = <<-END
    #cloud-config
    ${jsonencode({
  write_files = [
    {
      path        = "/var/www/html/webserver.py"
      permissions = "0644"
      owner       = "root:root"
      encoding    = "b64"
      content     = filebase64("${path.module}/webserver.py")
    },
    {
      path        = "/var/www/html/index.html"
      permissions = "0644"
      owner       = "root:root"
      encoding    = "b64"
      content     = filebase64("${path.module}/index.html") 
    }
  ]
})}
  END
}

data "cloudinit_config" "web" {
  gzip          = false
  base64_encode = false

  part {
    content_type = "text/cloud-config"
    filename     = "webserver.py"
    content      = local.cloud_config_config
  }

    part {
    content_type = "text/cloud-config"
    filename     = "index.html"
    content      = local.cloud_config_config
  }

  part {
    content_type = "text/x-shellscript"
    filename     = "start_webserver.sh"
    content      = <<-EOF
      #!/bin/bash
      mkdir /var/www/html/
      sudo yum install python38 -y
      sudo alternatives --set python /usr/bin/python3.8
      cd /var/www/html/ && sudo python3 webserver.py &
    EOF
  }
}