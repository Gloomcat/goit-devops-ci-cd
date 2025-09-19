# Read the Argo CD initial admin password and Service info after install

data "kubernetes_secret" "argocd_admin" {
  metadata {
    name      = "argocd-initial-admin-secret"
    namespace = var.namespace
  }
  depends_on = [helm_release.argo_cd]
}

data "kubernetes_service" "argocd_server" {
  metadata {
    name      = "${var.release_name}-server"
    namespace = var.namespace
  }
  depends_on = [helm_release.argo_cd]
}

locals {
  # Be resilient when LoadBalancer ingress isn't ready yet: avoid coalesce() on all-null values
  argocd_host = try(
    data.kubernetes_service.argocd_server.status[0].load_balancer[0].ingress[0].hostname,
    data.kubernetes_service.argocd_server.status[0].load_balancer[0].ingress[0].ip,
    null
  )
  argocd_port   = try(data.kubernetes_service.argocd_server.spec[0].port[0].port, 80)
  argocd_scheme = local.argocd_port == 443 ? "https" : "http"
}

output "argocd_initial_admin_password" {
  description = "Initial Argo CD admin password"
  value       = "Run: kubectl -n ${var.namespace} get secret argocd-initial-admin-secret -o jsonpath={.data.password} | base64 -d"
  sensitive   = true
}

output "argocd_hostname" {
  description = "External Load Balancer hostname for Argo CD (if available)"
  value       = try(data.kubernetes_service.argocd_server.status[0].load_balancer[0].ingress[0].hostname, null)
}

output "argocd_ip" {
  description = "External Load Balancer IP for Argo CD (if available)"
  value       = try(data.kubernetes_service.argocd_server.status[0].load_balancer[0].ingress[0].ip, null)
}

output "argocd_url" {
  description = "Convenience URL for Argo CD server (auto-selects http/https by Service port)"
  value       = local.argocd_host != null ? "${local.argocd_scheme}://${local.argocd_host}" : null
}
