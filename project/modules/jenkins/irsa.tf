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
