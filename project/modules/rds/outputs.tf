# Outputs for RDS module (works for both standard RDS and Aurora)

output "engine" {
  description = "Database engine in use (postgres or aurora-postgresql)"
  value       = var.use_aurora ? var.engine_cluster : var.engine
}

output "host" {
  description = "Writer endpoint/hostname"
  value       = var.use_aurora ? aws_rds_cluster.aurora[0].endpoint : aws_db_instance.standard[0].address
}

output "reader_host" {
  description = "Reader endpoint for Aurora (null for standard RDS)"
  value       = var.use_aurora ? aws_rds_cluster.aurora[0].reader_endpoint : null
}

output "port" {
  description = "Database port"
  value       = var.use_aurora ? aws_rds_cluster.aurora[0].port : aws_db_instance.standard[0].port
}

output "db_name" {
  description = "Database name"
  value       = var.db_name
}

output "username" {
  description = "Master username"
  value       = var.username
}

output "security_group_id" {
  description = "Security group ID used by the database"
  value       = aws_security_group.rds.id
}

output "subnet_group_name" {
  description = "DB subnet group name"
  value       = aws_db_subnet_group.default.name
}

output "instance_id" {
  description = "DB instance identifier (null for Aurora)"
  value       = var.use_aurora ? null : aws_db_instance.standard[0].id
}

output "instance_arn" {
  description = "DB instance ARN (null for Aurora)"
  value       = var.use_aurora ? null : aws_db_instance.standard[0].arn
}

output "cluster_id" {
  description = "Aurora cluster identifier (null for standard RDS)"
  value       = var.use_aurora ? aws_rds_cluster.aurora[0].id : null
}

output "cluster_arn" {
  description = "Aurora cluster ARN (null for standard RDS)"
  value       = var.use_aurora ? aws_rds_cluster.aurora[0].arn : null
}

