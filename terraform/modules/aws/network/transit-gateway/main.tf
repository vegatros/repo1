resource "aws_ec2_transit_gateway" "this" {
  description                     = var.description != "" ? var.description : "${var.name} Transit Gateway"
  amazon_side_asn                 = var.amazon_side_asn
  default_route_table_association = var.default_route_table_association
  default_route_table_propagation = var.default_route_table_propagation
  dns_support                     = var.dns_support
  vpn_ecmp_support                = var.vpn_ecmp_support

  tags = merge(
    var.tags,
    {
      Name = var.name
    }
  )
}
