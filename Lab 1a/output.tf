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

#output "chrisbarm_ec2_public_instance_id" {
 #   value = aws_instance.chrisbarm_ec2_public01.id
#}

#output "chrisbarm_ec2_private_instance_id" {
 # value = aws_instance.chrisbarm_ec2_private01.id
#}

output "chrisbarm_rds_endpoint" {
  value = aws_db_instance.chrisbarm_rds01.address
}

output "chrisbarm_sns_topic_arn" {
  value = aws_sns_topic.chrisbarm_sns_topic01.arn
}

output "chrisbarm_log_group_name" {
  value = "/aws/ec2/${var.project_name}-rds-app"  # Log group managed outside of Terraform
}
output "chrisbarm_secret_arn" {
  value = aws_secretsmanager_secret.chrisbarm_db_secret.arn
}
output "chrisbarm_secret_name" {
  value = aws_secretsmanager_secret.chrisbarm_db_secret.name
}
output "chrisbarm_secret_version_id" {
  value = aws_secretsmanager_secret_version.chrisbarm_db_secret_version.version_id
}
output "chrisbarm_secret_version_stage" {
  value = aws_secretsmanager_secret_version.chrisbarm_db_secret_version.version_stages
}
