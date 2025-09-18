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
        create = true
        name   = var.service_account_name
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.jenkins_irsa_role[0].arn
        }
      }
    }
  })])
}
