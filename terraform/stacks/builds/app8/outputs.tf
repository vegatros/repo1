output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = var.vpc_cidr
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

output "test_instance_private_ip" {
  description = "Test instance private IP"
  value       = aws_instance.test.private_ip
}

output "jenkins_url" {
  description = "Jenkins dashboard URL"
  value       = "http://${aws_instance.test.private_ip}:8080"
}

output "ssh_command" {
  description = "SSH command to connect"
  value       = "ssh cada5000@${aws_instance.test.private_ip}"
}

output "jenkins_credentials" {
  description = "Jenkins access information"
  value = {
    url      = "http://${aws_instance.test.private_ip}:8080"
    user     = "cada5000"
    password = "REDACTED_PASSWORD"
    note     = "Initial admin password will be in /var/lib/jenkins/secrets/initialAdminPassword"
  }
}

output "vpn_config" {
  description = "VPN configuration details"
  value = {
    tunnel1_address = aws_vpn_connection.main.tunnel1_address
    tunnel1_psk     = aws_vpn_connection.main.tunnel1_preshared_key
    tunnel2_address = aws_vpn_connection.main.tunnel2_address
    tunnel2_psk     = aws_vpn_connection.main.tunnel2_preshared_key
  }
  sensitive = true
}

output "download_vpn_config_command" {
  description = "Command to download VPN configuration"
  value       = "aws ec2 describe-vpn-connections --vpn-connection-ids ${aws_vpn_connection.main.id} --query 'VpnConnections[0].CustomerGatewayConfiguration' --output text > vpn-config.xml"
}
