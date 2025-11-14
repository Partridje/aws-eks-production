###############################################################################
# Additional Security Group for EKS Cluster
# Optional - EKS creates a default security group
###############################################################################

# Get VPC ID from subnets
data "aws_subnet" "selected" {
  id = var.private_subnet_ids[0]
}

# Additional security group for cluster (optional)
resource "aws_security_group" "cluster" {
  count = var.create_cluster_security_group ? 1 : 0

  name_prefix = "${var.cluster_name}-cluster-"
  description = "Additional security group for EKS cluster ${var.cluster_name}"
  vpc_id      = data.aws_subnet.selected.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.cluster_name}-cluster-sg"
      Type = "cluster-additional"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Allow HTTPS from VPC for kubectl access
resource "aws_security_group_rule" "cluster_ingress_kubectl" {
  count = var.create_cluster_security_group ? 1 : 0

  security_group_id = aws_security_group.cluster[0].id
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [data.aws_subnet.selected.vpc_id != "" ? data.aws_vpc.selected[0].cidr_block : "10.0.0.0/16"]
  description       = "Allow kubectl access from VPC"
}

# Get VPC CIDR for ingress rule
data "aws_vpc" "selected" {
  count = var.create_cluster_security_group ? 1 : 0
  id    = data.aws_subnet.selected.vpc_id
}

# Allow all egress
resource "aws_security_group_rule" "cluster_egress_all" {
  count = var.create_cluster_security_group ? 1 : 0

  security_group_id = aws_security_group.cluster[0].id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound traffic"
}
