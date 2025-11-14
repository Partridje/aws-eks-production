###############################################################################
# NAT Gateways
# High Availability: One NAT Gateway per AZ (unless single_nat_gateway = true)
###############################################################################

locals {
  # Determine number of NAT Gateways
  nat_gateway_count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(local.availability_zones)) : 0
}

###############################################################################
# Elastic IPs for NAT Gateways
###############################################################################

resource "aws_eip" "nat" {
  count = local.nat_gateway_count

  domain = "vpc"

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-nat-eip-${local.availability_zones[count.index]}"
      Type = "nat-gateway"
      AZ   = local.availability_zones[count.index]
    }
  )

  depends_on = [aws_internet_gateway.main]
}

###############################################################################
# NAT Gateways
###############################################################################

resource "aws_nat_gateway" "main" {
  count = local.nat_gateway_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-nat-gw-${local.availability_zones[count.index]}"
      Type = "nat-gateway"
      AZ   = local.availability_zones[count.index]
    }
  )

  depends_on = [aws_internet_gateway.main]
}

###############################################################################
# Routes to NAT Gateway from Private Subnets
###############################################################################

resource "aws_route" "private_nat_gateway" {
  count = var.enable_nat_gateway ? length(local.availability_zones) : 0

  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"

  # If single NAT gateway, all private subnets use the first NAT GW
  # Otherwise, each private subnet uses the NAT GW in its AZ
  nat_gateway_id = var.single_nat_gateway ? aws_nat_gateway.main[0].id : aws_nat_gateway.main[count.index].id
}
