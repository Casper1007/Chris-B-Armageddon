output "chrisbarm_alb_arn" {
  value = aws_lb.chrisbarm_alb01.arn
}

output "chrisbarm_alb_dns_name" {
  value = aws_lb.chrisbarm_alb01.dns_name
}

output "chrisbarm_alb_tg_arn" {
  value = aws_lb_target_group.chrisbarm_tg01.arn
}

output "chrisbarm_acm_cert_arn" {
  value = aws_acm_certificate.bonus_b_cert.arn
}

output "chrisbarm_waf_arn" {
  value = var.enable_waf ? aws_wafv2_web_acl.chrisbarm_waf01[0].arn : null
}

output "chrisbarm_alb_dashboard_name" {
  value = aws_cloudwatch_dashboard.chrisbarm_alb_dashboard.dashboard_name
}
