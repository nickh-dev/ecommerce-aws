resource "aws_vpc" "ecommerce_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "EcommerceVPC"
  }
}

resource "aws_subnet" "public_subnet" {
  count                   = 3
  vpc_id                  = aws_vpc.ecommerce_vpc.id
  cidr_block              = cidrsubnet("10.0.0.0/16", 8, count.index)
  map_public_ip_on_launch = true
  availability_zone       = element(["eu-central-1a", "eu-central-1b", "eu-central-1c"], count.index)
  tags = {
    Name = "PublicSubnet-${count.index + 1}"
  }
}

resource "aws_subnet" "private_subnet" {
  count                   = 3
  vpc_id                  = aws_vpc.ecommerce_vpc.id
  cidr_block              = cidrsubnet("10.0.0.0/16", 8, count.index + 3)
  map_public_ip_on_launch = false
  availability_zone       = element(["eu-central-1a", "eu-central-1b", "eu-central-1c"], count.index)
  tags = {
    Name = "PrivateSubnet-${count.index + 1}"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.ecommerce_vpc.id
  tags = {
    Name = "InternetGateway"
  }

}
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.ecommerce_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "PublicRouteTable"
  }
}

resource "aws_route_table_association" "public_rta" {
  count          = 3
  subnet_id      = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.public_route_table.id
}
