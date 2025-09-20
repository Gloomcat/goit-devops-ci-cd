variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "kube_host" {
  description = "Kubernetes API server endpoint"
  type        = string
}

variable "kube_ca" {
  description = "Base64-encoded cluster CA certificate"
  type        = string
}

variable "cluster_region" {
  description = "AWS region of the EKS cluster"
  type        = string
}

variable "namespace" {
  description = "Namespace where monitoring stack will be installed"
  type        = string
  default     = "monitoring"
}

variable "release_name" {
  description = "Helm release name"
  type        = string
  default     = "kube-prometheus-stack"
}

variable "chart_version" {
  description = "Optional chart version; leave null to install the latest"
  type        = string
  default     = null
}

variable "helm_repo_url" {
  description = "Helm repository URL for kube-prometheus-stack"
  type        = string
  default     = "https://prometheus-community.github.io/helm-charts"
}

