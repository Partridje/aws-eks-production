###############################################################################
# EKS Node Groups - Launch Templates
#
# Defines launch templates for system and application node groups with:
# - EBS volume configuration (encrypted gp3)
# - IMDSv2 enforcement for security
# - Detailed monitoring
# - Custom user data for node bootstrap
###############################################################################

###############################################################################
# System Node Group Launch Template
###############################################################################

resource "aws_launch_template" "system" {
  name_prefix = "${var.cluster_name}-system-"
  description = "Launch template for EKS system node group - runs critical cluster addons"

  # EBS Volume Configuration
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.system_node_disk_size
      volume_type           = "gp3"
      iops                  = 3000
      throughput            = 125
      encrypted             = true
      delete_on_termination = true
    }
  }

  # IMDSv2 Configuration (Security Best Practice)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # Enforce IMDSv2
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  # Enable Detailed Monitoring
  monitoring {
    enabled = true
  }

  # Network Interfaces (EKS manages this, but we can set security groups if needed)
  # network_interfaces {
  #   associate_public_ip_address = false
  #   delete_on_termination       = true
  # }

  # Instance Tags
  tag_specifications {
    resource_type = "instance"

    tags = merge(
      var.tags,
      {
        Name                                            = "${var.cluster_name}-system-node"
        Type                                            = "system"
        "kubernetes.io/cluster/${var.cluster_name}"     = "owned"
        "k8s.io/cluster-autoscaler/enabled"             = "true"
        "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
      }
    )
  }

  tag_specifications {
    resource_type = "volume"

    tags = merge(
      var.tags,
      {
        Name = "${var.cluster_name}-system-node-volume"
        Type = "system"
      }
    )
  }

  # User Data for Node Bootstrap
  user_data = base64encode(templatefile("${path.module}/user-data.sh", {
    cluster_name = var.cluster_name
    node_type    = "system"
  }))

  tags = merge(
    var.tags,
    {
      Name   = "${var.cluster_name}-system-launch-template"
      Type   = "system"
      Module = "eks-node-groups"
    }
  )
}

###############################################################################
# Application Node Group Launch Template
###############################################################################

resource "aws_launch_template" "app" {
  name_prefix = "${var.cluster_name}-app-"
  description = "Launch template for EKS application node group - runs user workloads"

  # EBS Volume Configuration
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.app_node_disk_size
      volume_type           = "gp3"
      iops                  = 3000
      throughput            = 125
      encrypted             = true
      delete_on_termination = true
    }
  }

  # IMDSv2 Configuration (Security Best Practice)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # Enforce IMDSv2
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  # Enable Detailed Monitoring
  monitoring {
    enabled = true
  }

  # Instance Tags
  tag_specifications {
    resource_type = "instance"

    tags = merge(
      var.tags,
      {
        Name                                            = "${var.cluster_name}-app-node"
        Type                                            = "application"
        "kubernetes.io/cluster/${var.cluster_name}"     = "owned"
        "k8s.io/cluster-autoscaler/enabled"             = "true"
        "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
      }
    )
  }

  tag_specifications {
    resource_type = "volume"

    tags = merge(
      var.tags,
      {
        Name = "${var.cluster_name}-app-node-volume"
        Type = "application"
      }
    )
  }

  # User Data for Node Bootstrap
  user_data = base64encode(templatefile("${path.module}/user-data.sh", {
    cluster_name = var.cluster_name
    node_type    = "app"
  }))

  tags = merge(
    var.tags,
    {
      Name   = "${var.cluster_name}-app-launch-template"
      Type   = "application"
      Module = "eks-node-groups"
    }
  )
}
