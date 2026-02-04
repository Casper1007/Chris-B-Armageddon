############################################
# Bonus B - ALB + ACM + WAF + Dashboard
############################################

locals {
  chrisbarm_app_fqdn = "${var.app_subdomain}.${var.domain_name}"
}

resource "aws_acm_certificate" "bonus_b_cert" {
  domain_name       = local.chrisbarm_app_fqdn
  validation_method = var.certificate_validation_method
}

resource "aws_security_group" "chrisbarm_alb_sg01" {
  name        = "${local.name_prefix}-alb-sg01"
  description = "ALB security group"
  vpc_id      = aws_vpc.chrisbarm_vpc01.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description     = "HTTP to app"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.chrisbarm_ec2_sg01.id]
  }

  tags = {
    Name = "${local.name_prefix}-alb-sg01"
  }
}

resource "aws_security_group_rule" "chrisbarm_ec2_from_alb_http" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = aws_security_group.chrisbarm_ec2_sg01.id
  source_security_group_id = aws_security_group.chrisbarm_alb_sg01.id
  description              = "HTTP from ALB SG"
}

resource "aws_lb" "chrisbarm_alb01" {
  name               = "${local.name_prefix}-alb01"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.chrisbarm_alb_sg01.id]
  subnets            = aws_subnet.chrisbarm_public_subnets[*].id

  tags = {
    Name = "${local.name_prefix}-alb01"
  }
}

resource "aws_lb_target_group" "chrisbarm_tg01" {
  name        = "${local.name_prefix}-tg01"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.chrisbarm_vpc01.id
  target_type = "instance"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_target_group_attachment" "chrisbarm_tg_attach_private_ec2" {
  target_group_arn = aws_lb_target_group.chrisbarm_tg01.arn
  target_id        = aws_instance.chrisbarm_ec201_private_bonus.id
  port             = 80
}

resource "aws_lb_listener" "chrisbarm_http_80" {
  load_balancer_arn = aws_lb.chrisbarm_alb01.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "chrisbarm_https_443" {
  load_balancer_arn = aws_lb.chrisbarm_alb01.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.bonus_b_cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.chrisbarm_tg01.arn
  }
}

resource "aws_wafv2_web_acl" "chrisbarm_waf01" {
  count       = var.enable_waf ? 1 : 0
  name        = "${local.name_prefix}-waf01"
  description = "WAF for ALB"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "aws-managed-common"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-waf-common"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.name_prefix}-waf"
    sampled_requests_enabled   = true
  }
}

resource "aws_wafv2_web_acl_association" "chrisbarm_waf_assoc" {
  count        = var.enable_waf ? 1 : 0
  resource_arn = aws_lb.chrisbarm_alb01.arn
  web_acl_arn  = aws_wafv2_web_acl.chrisbarm_waf01[0].arn
}

resource "aws_cloudwatch_metric_alarm" "chrisbarm_alb_5xx_alarm01" {
  alarm_name          = "${local.name_prefix}-alb-5xx"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.alb_5xx_evaluation_periods
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = var.alb_5xx_period_seconds
  statistic           = "Sum"
  threshold           = var.alb_5xx_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.chrisbarm_alb01.arn_suffix
  }

  alarm_actions = [aws_sns_topic.chrisbarm_sns_topic01.arn]
}

resource "aws_cloudwatch_dashboard" "chrisbarm_alb_dashboard" {
  dashboard_name = "${local.name_prefix}-alb-dashboard"
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.chrisbarm_alb01.arn_suffix],
            [".", "HTTPCode_ELB_5XX_Count", ".", "."],
            [".", "TargetResponseTime", ".", "."]
          ],
          view    = "timeSeries",
          stacked = false,
          region  = var.aws_region,
          title   = "ALB Requests + 5XX + Target Response Time"
        }
      }
    ]
  })
}
