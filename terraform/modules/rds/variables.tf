variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev or prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID from the VPC module"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs from the VPC module"
  type        = list(string)
}

variable "db_name" {
  description = "Name of the database"
  type        = string
  default     = "kindcare"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "kindcare"
}

variable "db_password" {
  description = "Database master password"
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "RDS instance type"
  type        = string
  default     = "db.t3.micro"
}

variable "eks_security_group_id" {
  description = "Security group ID of EKS nodes so they can reach RDS"
  type        = string
}