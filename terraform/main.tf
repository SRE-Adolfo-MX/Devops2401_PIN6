provider "aws" {
  region = "us-east-1"
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

# Asociar la ruta de internet para la subred pública
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

# Grupo de seguridad para permitir SSH y HTTP
resource "aws_security_group" "allow_ssh_http" {
  name        = "allow_ssh_http"
  description = "Allow SSH and HTTP inbound traffic"
  vpc_id      = aws_vpc.main_vpc.id

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

  tags = {
    Name = "AllowSSHHTTP"
  }
}

# Crear una instancia EC2 dentro de la VPC y la subred
resource "aws_instance" "ubuntu_server" {
  ami           = "ami-042e8287309f5df03" # Ubuntu Server 22.04 LTS para us-east-1
  instance_type = "t2.micro"
  key_name      = aws_key_pair.pin.key_name
  subnet_id     = aws_subnet.public_subnet.id

  security_groups = [
    aws_security_group.allow_ssh_http.name
  ]

  user_data = data.template_file.user_data.rendered

  tags = {
    Name = "UbuntuServerTerraform"
  }
}
