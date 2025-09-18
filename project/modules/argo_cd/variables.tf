variable "cluster_name" {
  description = "Name of the EKS cluster to connect to"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace to deploy Argo CD into"
  type        = string
  default     = "argocd"
}

variable "release_name" {
  description = "Helm release name for Argo CD"
  type        = string
  default     = "argo-cd"
}

variable "chart_version" {
  description = "Version of the Argo CD Helm chart. Leave null to use the latest available"
  type        = string
  default     = null
}

variable "helm_repo_url" {
  description = "Helm repository URL for Argo CD chart"
  type        = string
  default     = "https://argoproj.github.io/argo-helm"
}

variable "kube_host" {
  description = "Kubernetes API server endpoint for the cluster"
  type        = string
}

variable "kube_ca" {
  description = "Base64-encoded cluster CA data for the Kubernetes API server"
  type        = string
}

variable "cluster_region" {
  description = "AWS region of the EKS cluster (used by exec auth)"
  type        = string
  default     = "eu-north-1"
}

variable "image_repository" {
  description = "ECR repository URL for application images (used by Application helm.values). Leave empty to skip."
  type        = string
  default     = ""
}

variable "image_tag" {
  description = "Default application image tag to deploy (optional). Leave empty to use chart default."
  type        = string
  default     = ""
}

variable "values_overrides" {
  description = "Additional Helm values as YAML strings to overlay on top of the module's values.yaml"
  type        = list(string)
  default     = []
}
