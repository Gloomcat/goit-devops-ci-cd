resource "helm_release" "kube_prometheus_stack" {
  name             = var.release_name
  repository       = var.helm_repo_url
  chart            = "kube-prometheus-stack"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true

  values = [
    file("${path.module}/values.yaml"),
  ]
}
