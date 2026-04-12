output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "vpn_connection_id" {
  description = "VPN Connection ID"
  value       = aws_vpn_connection.main.id
}

output "customer_gateway_id" {
  description = "Customer Gateway ID"
  value       = aws_customer_gateway.main.id
}

output "vpn_gateway_id" {
  description = "Virtual Private Gateway ID"
  value       = aws_vpn_gateway.main.id
}

output "vpn_config" {
  description = "VPN tunnel configuration"
  value = {
    tunnel1_address = aws_vpn_connection.main.tunnel1_address
    tunnel2_address = aws_vpn_connection.main.tunnel2_address
  }
  sensitive = true
}

output "download_vpn_config_command" {
  description = "Command to download VPN configuration"
  value       = "aws ec2 describe-vpn-connections --vpn-connection-ids ${aws_vpn_connection.main.id} --query 'VpnConnections[0].CustomerGatewayConfiguration' --output text > vpn-config.xml"
}
