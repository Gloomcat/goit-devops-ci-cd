variable "cluster_name" {
  description = "Name of the EKS cluster to connect to"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace to deploy Jenkins into"
  type        = string
  default     = "jenkins"
}

variable "release_name" {
  description = "Helm release name for Jenkins"
  type        = string
  default     = "jenkins"
}

variable "chart_version" {
  description = "Version of the Jenkins Helm chart. Pin to a known-good version to avoid repo resolution issues"
  type        = string
  default     = "5.8.90"
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

variable "irsa_enabled" {
  description = "Enable creation of an IRSA role for Jenkins to access AWS (e.g., ECR)"
  type        = bool
  default     = false
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS cluster OIDC provider (from EKS module)"
  type        = string
  default     = ""
}

variable "oidc_provider_url" {
  description = "URL of the EKS cluster OIDC provider (from EKS module)"
  type        = string
  default     = ""
}

variable "ecr_repository_arn" {
  description = "ARN of the ECR repository Jenkins should push to (limits policy scope)"
  type        = string
  default     = ""
}

variable "service_account_name" {
  description = "ServiceAccount name for Jenkins controller"
  type        = string
  default     = "jenkins"
}
