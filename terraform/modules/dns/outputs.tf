output "name_servers" {
  description = "Route 53 nameservers - update these in Name.com"
  value       = aws_route53_zone.main.name_servers
}

output "kindcare_domain" {
  value = aws_route53_record.kindcare.fqdn
}

output "grafana_domain" {
  value = aws_route53_record.grafana.fqdn
}
