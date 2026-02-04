# Explanation: Outputs are your mission report—what got built and where to find it.
output "chrisbarm_vpc_id" {
  value = aws_vpc.chrisbarm_vpc01.id
}

output "chrisbarm_public_subnet_ids" {
  value = aws_subnet.chrisbarm_public_subnets[*].id
}

output "chrisbarm_private_subnet_ids" {
  value = aws_subnet.chrisbarm_private_subnets[*].id
}

output "chrisbarm_ec2_instance_id" {
  value = aws_instance.chrisbarm_ec201.id
}

output "chrisbarm_rds_endpoint" {
  value = aws_db_instance.chrisbarm_rds01.address
}

output "chrisbarm_sns_topic_arn" {
  value = aws_sns_topic.chrisbarm_sns_topic01.arn
}

output "chrisbarm_log_group_name" {
  value = aws_cloudwatch_log_group.chrisbarm_log_group01.name
}

# Explanation: Outputs are the nav computer readout - coordinates humans can paste into browsers.
output "chewbacca_app_url_https" {
  value = "https://${var.app_subdomain}.${var.domain_name}"
}
