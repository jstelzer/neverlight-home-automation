output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.test.id
}

output "instance_private_ip" {
  description = "Private IP of test instance"
  value       = aws_instance.test.private_ip
}

output "nat_gateway_ip" {
  description = "NAT Gateway public IP"
  value       = aws_eip.nat.public_ip
}
