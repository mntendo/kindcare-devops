output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "rds_endpoint" {
  description = "RDS endpoint for application config"
  value       = module.rds.db_endpoint
}

output "rds_db_name" {
  description = "Database name"
  value       = module.rds.db_name
}

output "name_servers" {
  description = "Update these in Name.com"
  value       = module.dns.name_servers
}

output "kindcare_url" {
  value = "https://${module.dns.kindcare_domain}"
}

output "grafana_url" {
  value = "https://${module.dns.grafana_domain}"
}
