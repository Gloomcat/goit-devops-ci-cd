# S3 module aggreagated outputs

output "s3_backend_bucket_url" {
  description = "S3 bucket URL for Terraform state"
  value       = module.s3_backend.s3_bucket_url
}

output "s3_backend_dynamodb_table_name" {
  description = "DynamoDB table name for Terraform state locking"
  value       = module.s3_backend.dynamodb_table_name
}

# ECR module aggregated outputs
output "ecr_repository_url" {
  description = "The URL of the ECR repository"
  value       = module.ecr.repository_url
}

output "ecr_repository_arn" {
  description = "The ARN of the ECR repository"
  value       = module.ecr.repository_arn
}

# VPC module aggregated outputs
output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnet_ids
}

output "internet_gateway_id" {
  description = "The ID of the Internet Gateway"
  value       = module.vpc.internet_gateway_id
}

output "nat_gateway_id" {
  description = "The ID of the NAT Gateway"
  value       = module.vpc.nat_gateway_id
}

# EKS module aggregated outputs
output "eks_cluster_endpoint" {
  description = "EKS API endpoint for connecting to the cluster"
  value       = module.eks.eks_cluster_endpoint
}

output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.eks_cluster_name
}

output "eks_node_role_arn" {
  description = "IAM role ARN for EKS Worker Nodes"
  value       = module.eks.eks_node_role_arn
}


# Jenkins module aggregated outputs
output "jenkins_url" {
  description = "URL for Jenkins UI"
  value       = try(module.jenkins.jenkins_url, null)
}

output "jenkins_admin_password" {
  description = "Initial Jenkins admin password"
  value       = try(module.jenkins.jenkins_admin_password, null)
  sensitive   = true
}

# Argo CD module aggregated outputs
output "argocd_url" {
  description = "URL for the Argo CD UI"
  value       = try(module.argo_cd.argocd_url, null)
}

output "argocd_initial_admin_password" {
  description = "Initial Argo CD admin password"
  value       = try(module.argo_cd.argocd_initial_admin_password, null)
  sensitive   = true
}
