# Вхідні змінні для модуля VPC

variable "vpc_cidr_block" {
  type        = string
  description = "CIDR block for the VPC"
}

variable "public_subnets" {
  type        = list(string)
  description = "List of CIDR blocks for public subnets"
}

variable "private_subnets" {
  type        = list(string)
  description = "List of CIDR blocks for private subnets"
}

variable "availability_zones" {
  type        = list(string)
  description = "List of availability zones, aligned by index with subnets"
}

variable "vpc_name" {
  type        = string
  description = "Name tag for the VPC"
}

variable "create_nat_gateway" {
  type        = bool
  description = "Whether to create a NAT Gateway and private routing for outbound internet access from private subnets"
  default     = true
}
