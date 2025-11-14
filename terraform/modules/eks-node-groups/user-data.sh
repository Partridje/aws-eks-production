#!/bin/bash
set -ex

###############################################################################
# EKS Node Bootstrap Script
# This script is executed on EC2 instance launch to join the EKS cluster
###############################################################################

# Variables provided by Terraform template
CLUSTER_NAME="${cluster_name}"
NODE_TYPE="${node_type}"

# Wait for network to be ready
until ping -c1 www.google.com &>/dev/null; do
  echo "Waiting for network..."
  sleep 1
done

# Bootstrap the node with EKS
# The bootstrap script is provided by the EKS-optimized AMI
/etc/eks/bootstrap.sh "$${CLUSTER_NAME}" \
  --kubelet-extra-args "--node-labels=node.kubernetes.io/type=$${NODE_TYPE},workload-type=$${NODE_TYPE}"

# Enable detailed monitoring via CloudWatch
# The CloudWatch agent is pre-installed on EKS-optimized AMIs

# Log completion
echo "Node bootstrap completed for $${NODE_TYPE} node in cluster $${CLUSTER_NAME}"
echo "Node will register with API server shortly"

# Additional custom configuration can be added here
# Examples:
# - Install custom monitoring agents
# - Configure log forwarding
# - Set up node-level security policies
