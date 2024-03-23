
# Collecting Avialabilty Zones 

data "aws_availability_zones" "az" {
  state = "available"
}


# use data source to get a registered ubuntu ami

data "aws_ami" "ubuntu" {

  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}


# VPC Creation 

resource "aws_vpc" "main" {
  cidr_block           =  var.vpc_cidr
  instance_tenancy     = "default"
  enable_dns_support   = "true"
  enable_dns_hostnames = "true"

  tags = {
    Name = "${var.Task}-vpc"
  }
}

# Internet GateWay Creation


resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.Task}-igw"
  }
}



# Public Subnet - 1 

resource "aws_subnet" "public1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.az.names[0]
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.Task}-public1"
  }
}

# Public Subnet - 2 

resource "aws_subnet" "public2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.az.names[1]
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.Task}-public2"
  }
}

# Private Subnet - 1

resource "aws_subnet" "private1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = data.aws_availability_zones.az.names[0]
  tags = {
    Name = "${var.Task}-private1"
  }
}

#private subnet - 2

resource "aws_subnet" "private2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = data.aws_availability_zones.az.names[1]
  tags = {
    Name = "${var.Task}-private2"
  }
}

# Route Table Public

resource "aws_route_table" "route-public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "${var.Task}-public-route"
  }
}


# Route Table Association Public


resource "aws_route_table_association" "public1" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.route-public.id
}

resource "aws_route_table_association" "public2" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.route-public.id
}

# Elastic IP

resource "aws_eip" "nat-eip" {

  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name = "${var.Task}-eip"
  }
}


# Nat GateWay

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat-eip.id
  subnet_id     = aws_subnet.public1.id
  depends_on    = [aws_eip.nat-eip]
  tags = {
    Name = "${var.Task}-nat"
  }
}

# Route Table Private

resource "aws_route_table" "route-private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat.id
  }
  tags = {
    Name = "${var.Task}-private-route"
  }
}

# Route Table Association Private

resource "aws_route_table_association" "private1" {
  subnet_id      = aws_subnet.private1.id
  route_table_id = aws_route_table.route-private.id
}

resource "aws_route_table_association" "private2" {
  subnet_id      = aws_subnet.private2.id
  route_table_id = aws_route_table.route-private.id
}

# Bastion Security Group

resource "aws_security_group" "bastion" {

  name_prefix = "${var.Task}-bsg--"
  description = "allows 22"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH Access"
    from_port   = 22
    to_port     = 22
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
    Name = "${var.Task}-bastion"
  }
}

# Web-Application Security Group


resource "aws_security_group" "sg" {

  name_prefix = "${var.Task}-sg--"
  description = "allows 80 443 22"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP/HTTPS Access"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.lb_sg.id]
  }

  ingress {
    description     = "HTTPS Access"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.lb_sg.id]
  }

 ingress {
    description     = "HTTP Access"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.lb_sg.id]
  }


  ingress {
    description = "SSH Access"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {

    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }




  tags = {
    Name = "${var.Task}-sg"
  }


}

# Load- balancer Security Group


resource "aws_security_group" "lb_sg" {

  name_prefix = "${var.Task}-lb_sg--"
  description = "allows 80 443 "
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP/HTTPS Access"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP Access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS Access"
    from_port   = 443
    to_port     = 443
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
    Name = "${var.Task}-lb_sg"
  }


}

















