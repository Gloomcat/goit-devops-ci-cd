locals {
  oidc_url_noscheme = replace(var.oidc_provider_url, "https://", "")
}

resource "aws_iam_role" "jenkins_irsa_role" {
  count = 1

  name = "${var.cluster_name}-jenkins-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.oidc_url_noscheme}:sub" = "system:serviceaccount:${var.namespace}:${var.service_account_name}"
            "${local.oidc_url_noscheme}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "jenkins_ecr_policy" {
  count = 1

  name = "${var.cluster_name}-jenkins-ecr"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:GetDownloadUrlForLayer",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
          "ecr:BatchGetImage",
          "ecr:DescribeRepositories",
          "ecr:ListImages"
        ]
        Resource = var.ecr_repository_arn != "" ? var.ecr_repository_arn : "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "jenkins_ecr_attach" {
  count = 1

  role       = aws_iam_role.jenkins_irsa_role[0].name
  policy_arn = aws_iam_policy.jenkins_ecr_policy[0].arn
}

resource "kubernetes_namespace_v1" "jenkins_ns" {
  metadata {
    name = var.namespace
  }
}


resource "kubernetes_service_account" "jenkins_sa" {
  metadata {
    name      = var.service_account_name
    namespace = var.namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.jenkins_irsa_role[0].arn
    }
  }

  depends_on = [
    kubernetes_namespace_v1.jenkins_ns
  ]
}

# Cluster-level default StorageClass for EBS CSI (gp3)
resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner = "ebs.csi.aws.com"
  volume_binding_mode = "WaitForFirstConsumer"

  parameters = {
    type   = "gp3"
    fsType = "ext4"
  }
}


resource "helm_release" "jenkins" {
  name             = var.release_name
  repository       = "https://charts.jenkins.io"
  chart            = "jenkins"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true
  timeout          = 1200 # seconds; Jenkins can take time due to LB + plugins

  values = concat([
    file("${path.module}/values.yaml"),
  ], [yamlencode({
    controller = {
      serviceAccount = {
        # ServiceAccount is managed by Terraform (in this module)
        create = false
        name   = var.service_account_name
      }
    }
  })])

  depends_on = [
    kubernetes_service_account.jenkins_sa
  ]
}
