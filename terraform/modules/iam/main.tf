# IAM Module
# Creates IAM roles for Service Accounts (IRSA) for:
# - Cluster Autoscaler
# - AWS Load Balancer Controller
# - External Secrets
# - Cert Manager
# - External DNS
# - EBS CSI Controller
# - Fluent Bit (CloudWatch Logs)
# - Grafana (CloudWatch read)
# - X-Ray Daemon
# - GitHub Actions OIDC

data "aws_caller_identity" "current" {}

data "tls_certificate" "cluster" {
  url = var.cluster_oidc_issuer_url
}

################################################################################
# OIDC Provider for EKS
################################################################################

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = var.cluster_oidc_issuer_url

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-eks-oidc-provider"
    }
  )
}

################################################################################
# Cluster Autoscaler Role
################################################################################

module "cluster_autoscaler_role" {
  source = "./irsa"

  role_name                 = "${var.cluster_name}-cluster-autoscaler"
  oidc_provider_arn         = aws_iam_openid_connect_provider.eks.arn
  oidc_provider_url         = var.cluster_oidc_issuer_url
  service_account_name      = "cluster-autoscaler"
  service_account_namespace = "kube-system"

  policy_arns = []

  inline_policies = {
    cluster_autoscaler = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "autoscaling:DescribeAutoScalingGroups",
            "autoscaling:DescribeAutoScalingInstances",
            "autoscaling:DescribeLaunchConfigurations",
            "autoscaling:DescribeScalingActivities",
            "autoscaling:DescribeTags",
            "ec2:DescribeInstanceTypes",
            "ec2:DescribeLaunchTemplateVersions"
          ]
          Resource = "*"
        },
        {
          Effect = "Allow"
          Action = [
            "autoscaling:SetDesiredCapacity",
            "autoscaling:TerminateInstanceInAutoScalingGroup",
            "ec2:DescribeImages",
            "ec2:GetInstanceTypesFromInstanceRequirements",
            "eks:DescribeNodegroup"
          ]
          Resource = "*"
        }
      ]
    })
  }

  tags = var.tags
}

################################################################################
# AWS Load Balancer Controller Role
################################################################################

module "aws_load_balancer_controller_role" {
  source = "./irsa"

  role_name                 = "${var.cluster_name}-aws-lb-controller"
  oidc_provider_arn         = aws_iam_openid_connect_provider.eks.arn
  oidc_provider_url         = var.cluster_oidc_issuer_url
  service_account_name      = "aws-load-balancer-controller"
  service_account_namespace = "kube-system"

  policy_arns = []

  # Policy from https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
  inline_policies = {
    aws_lb_controller = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "iam:CreateServiceLinkedRole"
          ]
          Resource = "*"
          Condition = {
            StringEquals = {
              "iam:AWSServiceName" = "elasticloadbalancing.amazonaws.com"
            }
          }
        },
        {
          Effect = "Allow"
          Action = [
            "ec2:DescribeAccountAttributes",
            "ec2:DescribeAddresses",
            "ec2:DescribeAvailabilityZones",
            "ec2:DescribeInternetGateways",
            "ec2:DescribeVpcs",
            "ec2:DescribeVpcPeeringConnections",
            "ec2:DescribeSubnets",
            "ec2:DescribeSecurityGroups",
            "ec2:DescribeInstances",
            "ec2:DescribeNetworkInterfaces",
            "ec2:DescribeTags",
            "ec2:GetCoipPoolUsage",
            "ec2:DescribeCoipPools",
            "elasticloadbalancing:DescribeLoadBalancers",
            "elasticloadbalancing:DescribeLoadBalancerAttributes",
            "elasticloadbalancing:DescribeListeners",
            "elasticloadbalancing:DescribeListenerCertificates",
            "elasticloadbalancing:DescribeSSLPolicies",
            "elasticloadbalancing:DescribeRules",
            "elasticloadbalancing:DescribeTargetGroups",
            "elasticloadbalancing:DescribeTargetGroupAttributes",
            "elasticloadbalancing:DescribeTargetHealth",
            "elasticloadbalancing:DescribeTags"
          ]
          Resource = "*"
        },
        {
          Effect = "Allow"
          Action = [
            "cognito-idp:DescribeUserPoolClient",
            "acm:ListCertificates",
            "acm:DescribeCertificate",
            "iam:ListServerCertificates",
            "iam:GetServerCertificate",
            "waf-regional:GetWebACL",
            "waf-regional:GetWebACLForResource",
            "waf-regional:AssociateWebACL",
            "waf-regional:DisassociateWebACL",
            "wafv2:GetWebACL",
            "wafv2:GetWebACLForResource",
            "wafv2:AssociateWebACL",
            "wafv2:DisassociateWebACL",
            "shield:GetSubscriptionState",
            "shield:DescribeProtection",
            "shield:CreateProtection",
            "shield:DeleteProtection"
          ]
          Resource = "*"
        },
        {
          Effect = "Allow"
          Action = [
            "ec2:AuthorizeSecurityGroupIngress",
            "ec2:RevokeSecurityGroupIngress"
          ]
          Resource = "*"
        },
        {
          Effect = "Allow"
          Action = [
            "ec2:CreateSecurityGroup"
          ]
          Resource = "*"
        },
        {
          Effect = "Allow"
          Action = [
            "ec2:CreateTags"
          ]
          Resource = "arn:aws:ec2:*:*:security-group/*"
          Condition = {
            StringEquals = {
              "ec2:CreateAction" = "CreateSecurityGroup"
            }
            Null = {
              "aws:RequestTag/elbv2.k8s.aws/cluster" = "false"
            }
          }
        },
        {
          Effect = "Allow"
          Action = [
            "ec2:CreateTags",
            "ec2:DeleteTags"
          ]
          Resource = "arn:aws:ec2:*:*:security-group/*"
          Condition = {
            Null = {
              "aws:RequestTag/elbv2.k8s.aws/cluster"  = "true"
              "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
            }
          }
        },
        {
          Effect = "Allow"
          Action = [
            "ec2:AuthorizeSecurityGroupIngress",
            "ec2:RevokeSecurityGroupIngress",
            "ec2:DeleteSecurityGroup"
          ]
          Resource = "*"
          Condition = {
            Null = {
              "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
            }
          }
        },
        {
          Effect = "Allow"
          Action = [
            "elasticloadbalancing:CreateLoadBalancer",
            "elasticloadbalancing:CreateTargetGroup"
          ]
          Resource = "*"
          Condition = {
            Null = {
              "aws:RequestTag/elbv2.k8s.aws/cluster" = "false"
            }
          }
        },
        {
          Effect = "Allow"
          Action = [
            "elasticloadbalancing:CreateListener",
            "elasticloadbalancing:DeleteListener",
            "elasticloadbalancing:CreateRule",
            "elasticloadbalancing:DeleteRule"
          ]
          Resource = "*"
        },
        {
          Effect = "Allow"
          Action = [
            "elasticloadbalancing:AddTags",
            "elasticloadbalancing:RemoveTags"
          ]
          Resource = [
            "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
            "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
            "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
          ]
          Condition = {
            Null = {
              "aws:RequestTag/elbv2.k8s.aws/cluster"  = "true"
              "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
            }
          }
        },
        {
          Effect = "Allow"
          Action = [
            "elasticloadbalancing:AddTags",
            "elasticloadbalancing:RemoveTags"
          ]
          Resource = [
            "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
            "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
            "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
            "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*"
          ]
        },
        {
          Effect = "Allow"
          Action = [
            "elasticloadbalancing:ModifyLoadBalancerAttributes",
            "elasticloadbalancing:SetIpAddressType",
            "elasticloadbalancing:SetSecurityGroups",
            "elasticloadbalancing:SetSubnets",
            "elasticloadbalancing:DeleteLoadBalancer",
            "elasticloadbalancing:ModifyTargetGroup",
            "elasticloadbalancing:ModifyTargetGroupAttributes",
            "elasticloadbalancing:DeleteTargetGroup"
          ]
          Resource = "*"
          Condition = {
            Null = {
              "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
            }
          }
        },
        {
          Effect = "Allow"
          Action = [
            "elasticloadbalancing:AddTags"
          ]
          Resource = [
            "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
            "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
            "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
          ]
          Condition = {
            StringEquals = {
              "elasticloadbalancing:CreateAction" = [
                "CreateTargetGroup",
                "CreateLoadBalancer"
              ]
            }
            Null = {
              "aws:RequestTag/elbv2.k8s.aws/cluster" = "false"
            }
          }
        },
        {
          Effect = "Allow"
          Action = [
            "elasticloadbalancing:RegisterTargets",
            "elasticloadbalancing:DeregisterTargets"
          ]
          Resource = "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
        },
        {
          Effect = "Allow"
          Action = [
            "elasticloadbalancing:SetWebAcl",
            "elasticloadbalancing:ModifyListener",
            "elasticloadbalancing:AddListenerCertificates",
            "elasticloadbalancing:RemoveListenerCertificates",
            "elasticloadbalancing:ModifyRule"
          ]
          Resource = "*"
        }
      ]
    })
  }

  tags = var.tags
}

################################################################################
# External Secrets Role
################################################################################

module "external_secrets_role" {
  source = "./irsa"

  role_name                 = "${var.cluster_name}-external-secrets"
  oidc_provider_arn         = aws_iam_openid_connect_provider.eks.arn
  oidc_provider_url         = var.cluster_oidc_issuer_url
  service_account_name      = "external-secrets"
  service_account_namespace = "external-secrets"

  policy_arns = []

  inline_policies = {
    external_secrets = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "secretsmanager:GetResourcePolicy",
            "secretsmanager:GetSecretValue",
            "secretsmanager:DescribeSecret",
            "secretsmanager:ListSecretVersionIds"
          ]
          Resource = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.cluster_name}/*"
        },
        {
          Effect = "Allow"
          Action = [
            "secretsmanager:ListSecrets"
          ]
          Resource = "*"
        }
      ]
    })
  }

  tags = var.tags
}

################################################################################
# Cert Manager Role (Route53 DNS01 challenge)
################################################################################

module "cert_manager_role" {
  source = "./irsa"

  role_name                 = "${var.cluster_name}-cert-manager"
  oidc_provider_arn         = aws_iam_openid_connect_provider.eks.arn
  oidc_provider_url         = var.cluster_oidc_issuer_url
  service_account_name      = "cert-manager"
  service_account_namespace = "cert-manager"

  policy_arns = []

  inline_policies = {
    cert_manager = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "route53:GetChange"
          ]
          Resource = "arn:aws:route53:::change/*"
        },
        {
          Effect = "Allow"
          Action = [
            "route53:ChangeResourceRecordSets",
            "route53:ListResourceRecordSets"
          ]
          Resource = "arn:aws:route53:::hostedzone/${var.route53_zone_id}"
        },
        {
          Effect = "Allow"
          Action = [
            "route53:ListHostedZonesByName"
          ]
          Resource = "*"
        }
      ]
    })
  }

  tags = var.tags
}

################################################################################
# External DNS Role
################################################################################

module "external_dns_role" {
  source = "./irsa"

  role_name                 = "${var.cluster_name}-external-dns"
  oidc_provider_arn         = aws_iam_openid_connect_provider.eks.arn
  oidc_provider_url         = var.cluster_oidc_issuer_url
  service_account_name      = "external-dns"
  service_account_namespace = "external-dns"

  policy_arns = []

  inline_policies = {
    external_dns = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "route53:ChangeResourceRecordSets"
          ]
          Resource = "arn:aws:route53:::hostedzone/${var.route53_zone_id}"
        },
        {
          Effect = "Allow"
          Action = [
            "route53:ListHostedZones",
            "route53:ListResourceRecordSets"
          ]
          Resource = "*"
        }
      ]
    })
  }

  tags = var.tags
}

################################################################################
# EBS CSI Controller Role
################################################################################

module "ebs_csi_controller_role" {
  source = "./irsa"

  role_name                 = "${var.cluster_name}-ebs-csi-controller"
  oidc_provider_arn         = aws_iam_openid_connect_provider.eks.arn
  oidc_provider_url         = var.cluster_oidc_issuer_url
  service_account_name      = "ebs-csi-controller-sa"
  service_account_namespace = "kube-system"

  policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  ]

  inline_policies = {}

  tags = var.tags
}

################################################################################
# Fluent Bit Role (CloudWatch Logs)
################################################################################

module "fluent_bit_role" {
  source = "./irsa"

  role_name                 = "${var.cluster_name}-fluent-bit"
  oidc_provider_arn         = aws_iam_openid_connect_provider.eks.arn
  oidc_provider_url         = var.cluster_oidc_issuer_url
  service_account_name      = "fluent-bit"
  service_account_namespace = "amazon-cloudwatch"

  policy_arns = []

  inline_policies = {
    fluent_bit = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents",
            "logs:DescribeLogGroups",
            "logs:DescribeLogStreams"
          ]
          Resource = "*"
        }
      ]
    })
  }

  tags = var.tags
}

################################################################################
# Grafana Role (CloudWatch read)
################################################################################

module "grafana_role" {
  source = "./irsa"

  role_name                 = "${var.cluster_name}-grafana"
  oidc_provider_arn         = aws_iam_openid_connect_provider.eks.arn
  oidc_provider_url         = var.cluster_oidc_issuer_url
  service_account_name      = "grafana"
  service_account_namespace = "observability"

  policy_arns = []

  inline_policies = {
    grafana_cloudwatch = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "cloudwatch:DescribeAlarmsForMetric",
            "cloudwatch:DescribeAlarmHistory",
            "cloudwatch:DescribeAlarms",
            "cloudwatch:ListMetrics",
            "cloudwatch:GetMetricStatistics",
            "cloudwatch:GetMetricData",
            "cloudwatch:GetInsightRuleReport"
          ]
          Resource = "*"
        },
        {
          Effect = "Allow"
          Action = [
            "logs:DescribeLogGroups",
            "logs:GetLogGroupFields",
            "logs:StartQuery",
            "logs:StopQuery",
            "logs:GetQueryResults",
            "logs:GetLogEvents"
          ]
          Resource = "*"
        },
        {
          Effect = "Allow"
          Action = [
            "ec2:DescribeTags",
            "ec2:DescribeInstances",
            "ec2:DescribeRegions"
          ]
          Resource = "*"
        },
        {
          Effect = "Allow"
          Action = [
            "tag:GetResources"
          ]
          Resource = "*"
        }
      ]
    })
  }

  tags = var.tags
}

################################################################################
# X-Ray Daemon Role
################################################################################

module "xray_daemon_role" {
  source = "./irsa"

  role_name                 = "${var.cluster_name}-xray-daemon"
  oidc_provider_arn         = aws_iam_openid_connect_provider.eks.arn
  oidc_provider_url         = var.cluster_oidc_issuer_url
  service_account_name      = "xray-daemon"
  service_account_namespace = "amazon-cloudwatch"

  policy_arns = [
    "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
  ]

  inline_policies = {}

  tags = var.tags
}

################################################################################
# CloudWatch Agent Role (Container Insights)
################################################################################

module "cloudwatch_agent_role" {
  source = "./irsa"

  role_name                 = "${var.cluster_name}-cloudwatch-agent"
  oidc_provider_arn         = aws_iam_openid_connect_provider.eks.arn
  oidc_provider_url         = var.cluster_oidc_issuer_url
  service_account_name      = "cloudwatch-agent"
  service_account_namespace = "amazon-cloudwatch"

  policy_arns = [
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  ]

  inline_policies = {}

  tags = var.tags
}

################################################################################
# ArgoCD Role
################################################################################

module "argocd_role" {
  source = "./irsa"

  role_name                 = "${var.cluster_name}-argocd"
  oidc_provider_arn         = aws_iam_openid_connect_provider.eks.arn
  oidc_provider_url         = var.cluster_oidc_issuer_url
  service_account_name      = "argocd-application-controller"
  service_account_namespace = "argocd"

  policy_arns = []

  inline_policies = {
    argocd = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "ecr:GetAuthorizationToken",
            "ecr:BatchCheckLayerAvailability",
            "ecr:GetDownloadUrlForLayer",
            "ecr:BatchGetImage",
            "ecr:DescribeRepositories",
            "ecr:ListImages"
          ]
          Resource = "*"
        },
        {
          Effect = "Allow"
          Action = [
            "secretsmanager:GetSecretValue",
            "secretsmanager:DescribeSecret"
          ]
          Resource = "arn:aws:secretsmanager:*:${data.aws_caller_identity.current.account_id}:secret:${var.cluster_name}-*"
        }
      ]
    })
  }

  tags = var.tags
}
