terraform {
  backend "s3" {
    bucket         = "kirby-terraform-tfstate"
    key            = "ec2/terraform.tfstate"
    region         = "ap-northeast-1"
    dynamodb_table = "terraform-lock"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC
resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "${var.instance_name}-vpc"
  }
}

# パブリックサブネット
resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.subnet_cidr
  availability_zone = var.availability_zone

  tags = {
    Name = "${var.instance_name}-public-subnet"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.instance_name}-igw"
  }
}

# ルートテーブル
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${var.instance_name}-public-rt"
  }
}

# ルートテーブルとサブネットの関連付け
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# IAMロール（SSM用）
resource "aws_iam_role" "ssm" {
  name = "${var.instance_name}-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm" {
  name = "${var.instance_name}-ssm-profile"
  role = aws_iam_role.ssm.name
}

# EC2インスタンス
resource "aws_instance" "this" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ssm.name

  tags = {
    Name = var.instance_name
  }
}
