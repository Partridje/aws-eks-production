###############################################################################
# VPC Main Configuration
# Production-ready VPC for EKS with multi-AZ setup
###############################################################################

# Data source to get available AZs
data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# Local variables
locals {
  # Use provided AZs or auto-detect first 3 available
  availability_zones = length(var.azs) > 0 ? var.azs : slice(data.aws_availability_zones.available.names, 0, 3)

  # Common tags
  common_tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-vpc"
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Module      = "vpc"
    }
  )

  # EKS cluster tag
  eks_cluster_tag = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

###############################################################################
# VPC
###############################################################################

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    local.common_tags,
    local.eks_cluster_tag,
    {
      Name = "${var.project_name}-${var.environment}-vpc"
    }
  )
}

###############################################################################
# Internet Gateway
###############################################################################

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-igw"
    }
  )
}

###############################################################################
# Public Subnets
###############################################################################

resource "aws_subnet" "public" {
  count = length(local.availability_zones)

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index)
  availability_zone = local.availability_zones[count.index]

  map_public_ip_on_launch = true

  tags = merge(
    local.common_tags,
    local.eks_cluster_tag,
    {
      Name                     = "${var.project_name}-${var.environment}-public-${local.availability_zones[count.index]}"
      Type                     = "public"
      "kubernetes.io/role/elb" = "1"
    }
  )
}

###############################################################################
# Private Subnets
###############################################################################

resource "aws_subnet" "private" {
  count = length(local.availability_zones)

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + 3)
  availability_zone = local.availability_zones[count.index]

  tags = merge(
    local.common_tags,
    local.eks_cluster_tag,
    {
      Name                              = "${var.project_name}-${var.environment}-private-${local.availability_zones[count.index]}"
      Type                              = "private"
      "kubernetes.io/role/internal-elb" = "1"
    }
  )
}

###############################################################################
# Database Subnets
###############################################################################

resource "aws_subnet" "database" {
  count = length(local.availability_zones)

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 96)
  availability_zone = local.availability_zones[count.index]

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-database-${local.availability_zones[count.index]}"
      Type = "database"
    }
  )
}

###############################################################################
# Database Subnet Group
###############################################################################

resource "aws_db_subnet_group" "database" {
  name       = "${var.project_name}-${var.environment}-db-subnet-group"
  subnet_ids = aws_subnet.database[*].id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-db-subnet-group"
    }
  )
}

###############################################################################
# Route Tables
###############################################################################

# Public route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-public-rt"
      Type = "public"
    }
  )
}

# Public route to Internet Gateway
resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

# Public route table associations
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private route tables (one per AZ for NAT Gateway routing)
resource "aws_route_table" "private" {
  count = length(local.availability_zones)

  vpc_id = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-private-rt-${local.availability_zones[count.index]}"
      Type = "private"
      AZ   = local.availability_zones[count.index]
    }
  )
}

# Private route table associations
resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Database route table
resource "aws_route_table" "database" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-database-rt"
      Type = "database"
    }
  )
}

# Database route table associations
resource "aws_route_table_association" "database" {
  count = length(aws_subnet.database)

  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.database.id
}
