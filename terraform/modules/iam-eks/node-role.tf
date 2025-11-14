###############################################################################
# EKS Node Group IAM Role
# Role assumed by EC2 instances in EKS node groups
###############################################################################

# IAM role for EKS nodes
resource "aws_iam_role" "node" {
  name               = "${var.cluster_name}-node-role"
  assume_role_policy = data.aws_iam_policy_document.node_assume_role.json

  tags = merge(
    local.common_tags,
    {
      Name = "${var.cluster_name}-node-role"
      Type = "eks-node"
    }
  )
}

# Trust relationship for EC2 service
data "aws_iam_policy_document" "node_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

###############################################################################
# AWS Managed Policies for EKS Nodes
###############################################################################

# Core EKS node policy
resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node.name
}

# CNI policy for pod networking
resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node.name
}

# ECR read access for pulling container images
resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node.name
}

# SSM Session Manager access (optional but recommended)
resource "aws_iam_role_policy_attachment" "node_AmazonSSMManagedInstanceCore" {
  count = var.enable_ssm_access ? 1 : 0

  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.node.name
}

###############################################################################
# EC2 Instance Profile
###############################################################################

# Instance profile for EC2 instances to assume the node role
resource "aws_iam_instance_profile" "node" {
  name = "${var.cluster_name}-node-instance-profile"
  role = aws_iam_role.node.name

  tags = merge(
    local.common_tags,
    {
      Name = "${var.cluster_name}-node-instance-profile"
      Type = "eks-node"
    }
  )
}
