# Read the Jenkins admin password and Service info after install

data "kubernetes_secret" "jenkins_admin" {
  metadata {
    name      = helm_release.jenkins.name
    namespace = var.namespace
  }
  depends_on = [helm_release.jenkins]
}

data "kubernetes_service" "jenkins" {
  metadata {
    name      = helm_release.jenkins.name
    namespace = var.namespace
  }
  depends_on = [helm_release.jenkins]
}

locals {
  jenkins_host = coalesce(
    try(data.kubernetes_service.jenkins.status[0].load_balancer[0].ingress[0].hostname, null),
    try(data.kubernetes_service.jenkins.status[0].load_balancer[0].ingress[0].ip, null)
  )
}

output "jenkins_admin_password" {
  description = "Initial Jenkins admin password"
  value       = try(base64decode(data.kubernetes_secret.jenkins_admin.data["jenkins-admin-password"]), null)
  sensitive   = true
}

output "jenkins_hostname" {
  description = "External Load Balancer hostname for Jenkins (if available)"
  value       = try(data.kubernetes_service.jenkins.status[0].load_balancer[0].ingress[0].hostname, null)
}

output "jenkins_ip" {
  description = "External Load Balancer IP for Jenkins (if available)"
  value       = try(data.kubernetes_service.jenkins.status[0].load_balancer[0].ingress[0].ip, null)
}

output "jenkins_url" {
  description = "Convenience URL for Jenkins (assumes LoadBalancer; uses http on port 80)"
  value       = local.jenkins_host != null ? "http://${local.jenkins_host}" : null
}
