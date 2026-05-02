variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "kindcare"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "db_password" {
  description = "RDS master password"
  type        = string
  sensitive   = true
}

variable "load_balancer_hostname" {
  description = "Load balancer hostname - set after ingress is created"
  type        = string
  default     = "placeholder"
}
