data "aws_availability_zones" "available_azs" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available_azs.names, 0, 2)
}

resource "random_integer" "private_subnet_ids" {
  for_each = toset(local.azs)
  min      = 5
  max      = 6
}

resource "random_integer" "public_subnet_ids" {
  for_each = toset(local.azs)
  min      = 7
  max      = 8
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_subnet" "private" {
  for_each          = toset(local.azs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${random_integer.private_subnet_ids[each.key].result}.0/24"
  availability_zone = each.key
}

resource "aws_subnet" "public" {
  for_each                = toset(local.azs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${random_integer.public_subnet_ids[each.key].result}.0/24"
  availability_zone       = each.key
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_eip" "ngw_eip" {
  depends_on = [aws_internet_gateway.igw]
}
resource "aws_nat_gateway" "ngw" {
  subnet_id     = values(aws_subnet.public)[0].id
  allocation_id = aws_eip.ngw_eip.id
  depends_on    = [aws_internet_gateway.igw]

}
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_subnet_aws_route_table_association" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.ngw.id
  }
}

resource "aws_route_table_association" "private_subnet_aws_route_table_association" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_route_table.id
}
