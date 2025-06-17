output "vpc_arn" {
  description = "VPC arn"
  value       = aws_vpc.main.arn
}

output "vpc_id" {
  description = "VPC id"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC cidr block"
  value       = aws_vpc.main.cidr_block
}

output "main_private_subnet_id" {
  value       = values(aws_subnet.private)[0].id
  description = "Main Private Subnet ID"
}

output "secondary_private_subnet_id" {
  value       = values(aws_subnet.private)[1].id
  description = "Secondary Private Subnet ID"
}

output "main_public_subnet_id" {
  value       = values(aws_subnet.public)[0].id
  description = "Main Public Subnet ID"
}

output "secondary_public_subnet_id" {
  value       = values(aws_subnet.public)[1].id
  description = "Secondary Public Subnet ID"
}
