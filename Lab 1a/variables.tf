variable "aws_region" {
  description = "AWS Region for the lab environment."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project/name prefix used in tags and resource names."
  type        = string
  default     = "lab"
}

variable "vpc_cidr" {
  description = "VPC CIDR."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs (one per AZ)."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs (one per AZ)."
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "azs" {
  description = "Availability Zones list (match count with subnets)."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "ec2_instance_type" {
  description = "EC2 instance type for the app host."
  type        = string
  default     = "t3.micro"
}

variable "ec2_ami_id" {
  description = "Optional: Override AMI for EC2. Leave as null to auto-select Amazon Linux 2023."
  type        = string
  default     = null
}

variable "ssh_ingress_cidr" {
  description = "Optional: CIDR allowed to SSH to EC2 (e.g., your public IP /32). If null, SSH is disabled and you should use SSM Session Manager."
  type        = string
  default     = null
}

variable "http_ingress_cidrs" {
  description = "CIDRs allowed to reach the EC2 app over HTTP."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "db_engine" {
  description = "RDS engine."
  type        = string
  default     = "mysql"
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Initial database name."
  type        = string
  default     = "labdb"
}

variable "db_username" {
  description = "DB master username (stored in Secrets Manager)."
  type        = string
  default     = "admin"
}

variable "db_allocated_storage" {
  description = "Allocated storage (GB)."
  type        = number
  default     = 20
}
