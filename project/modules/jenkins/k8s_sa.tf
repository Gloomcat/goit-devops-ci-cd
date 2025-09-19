resource "kubernetes_service_account" "jenkins_sa" {
  metadata {
    name      = var.service_account_name
    namespace = var.namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.jenkins_irsa_role[0].arn
    }
  }
}

