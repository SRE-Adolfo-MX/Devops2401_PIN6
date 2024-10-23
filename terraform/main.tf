provider "aws" {
  region = "us-east-1"
}

# Crear un par de claves SSH
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "pin" {
  key_name   = "pin"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

# Crear una VPC
resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "MainVPC"
  }
}

# Crear subredes públicas dentro de la VPC
resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.main_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "PublicSubnet"
  }
}

# Crear un Internet Gateway para la VPC
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "MainInternetGateway"
  }
}

# Crear una tabla de rutas para la subred pública
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "PublicRouteTable"
  }
}

# Asociar la tabla de rutas a la subred pública
resource "aws_route_table_association" "public_subnet_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

# Grupo de seguridad que permite SSH y HTTP
resource "aws_security_group" "allow_ssh_http" {
  name        = "allow_ssh_http"
  description = "Allow SSH and HTTP inbound traffic"
  vpc_id      = aws_vpc.main_vpc.id  # Asociar el SG a la VPC

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
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

# Script de instalación en el user_data
data "template_file" "user_data" {
  template = <<EOF
#!/bin/bash
# Actualizar paquetes
sudo apt update -y
sudo apt upgrade -y

# Instalar AWS CLI
sudo apt install awscli -y

# Instalar Docker
sudo apt install docker.io -y
sudo systemctl start docker
sudo systemctl enable docker

# Instalar Kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Instalar Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Habilitar el uso de Docker sin sudo
sudo usermod -aG docker ubuntu

# Instalar NGINX y exponer puerto 80
sudo apt install nginx -y
sudo systemctl start nginx
sudo systemctl enable nginx
EOF
}

# Crear la instancia EC2 dentro de la VPC y subred
resource "aws_instance" "ubuntu_server" {
  ami           = "ami-042e8287309f5df03" # Ubuntu Server 22.04 LTS para us-east-1
  instance_type = "t2.micro"
  key_name      = aws_key_pair.pin.key_name
  subnet_id     = aws_subnet.public_subnet.id  # Asociar la instancia a la subred pública

  security_groups = [
    aws_security_group.allow_ssh_http.name
  ]

  user_data = data.template_file.user_data.rendered

  tags = {
    Name = "ubuntu_server_terraform"
  }
}

# Output para la clave privada en formato PEM
output "private_key_pem" {
  value     = tls_private_key.ssh_key.private_key_pem
  sensitive = true
}

# Output de la IP pública de la instancia
output "instance_public_ip" {
  value = aws_instance.ubuntu_server.public_ip
}
