# Create Route 53 hosted zone
resource "aws_route53_zone" "main" {
  name = "mariamdevops.com"

  tags = {
    Name        = "mariamdevops.com"
    Environment = var.environment
  }
}

# CNAME record for KindCare app
resource "aws_route53_record" "kindcare" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "kindcare.mariamdevops.com"
  type    = "CNAME"
  ttl     = 300
  records = [var.load_balancer_hostname]
}

# CNAME record for Grafana
resource "aws_route53_record" "grafana" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "grafana.mariamdevops.com"
  type    = "CNAME"
  ttl     = 300
  records = [var.load_balancer_hostname]
}
