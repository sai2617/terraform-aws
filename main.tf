provider "aws" {
  region = "us-east-1"
  access_key = "AKIAXWPXDLVGXLHVCRVJ"
  secret_key = "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"
}

# resource "aws_instance" "my-first-server"{
#     ami           ="ami-053b0d53c279acc90"
#     instance_type ="t2.micro"
    # tags = {
    #     Name = "ubuntu"
    # }
# }

#Create VPC
resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "production"
  }
}

#Create internet gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod-vpc.id

  # tags = {
  #   Name = "main"
  # }
}

# Create Custom route table
resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "prod"
  }
}

#create a subnet
resource "aws_subnet" "subnet-1"{
  vpc_id = aws_vpc.prod-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name ="prod-subnet"
  }
}

#Associate route table with subnet
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
}

#Create security group
resource "aws_security_group" "allow_tls" {
  name        = "allow_web_traffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 447
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    # ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }
  ingress {
    description      = "HTTPS"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    # ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }
  ingress {
    description      = "HTTPS"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    # ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    # ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

#create network interface
resource "aws_network_interface" "web-server-sai" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_tls.id]

}
#Assign elasticip to internet 
resource "aws_eip" "one"{
  vpc =true
  network_interface = aws_network_interface.web-server-sai.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.gw]
}

#create an ubuntu server
resource "aws_instance" "web-server-instance"{
  ami = "ami-053b0d53c279acc90"
  instance_type ="t2.micro"
  availability_zone = "us-east-1a"
  key_name = "main-key"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.web-server-sai.id
  }

  user_data = <<-EOF
               #!/bin/bash
               sudo apt update -y
               sudo apt install apache2 -y
               sudo systemctl start apache2
               sudo bash -c 'echo your very first web server > /var/www/html/index.html'
               EOF

    tags = {
      Name = "web-server"
    }
}

#for checking output needed
# output{}