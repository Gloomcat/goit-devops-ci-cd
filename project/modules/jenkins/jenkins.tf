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
        # ServiceAccount is managed by Terraform (see k8s_sa.tf)
        create = false
        name   = var.service_account_name
      }
    }
  })])

  depends_on = [
    kubernetes_service_account.jenkins_sa
  ]
}
