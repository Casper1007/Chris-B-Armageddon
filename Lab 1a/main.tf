############################################
# EC2 → RDS Integration Lab
# Foundational Cloud Application Pattern
############################################

############################################
# Locals
############################################
locals {
  name_prefix  = var.project_name
  ports_http   = 80
  ports_ssh    = 22
  db_port      = 3306
  tcp_protocol = "tcp"
  all_ipv4     = "0.0.0.0/0"
}

############################################
# VPC + Internet Gateway
############################################
resource "aws_vpc" "chrisbarm_vpc01" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.name_prefix}-vpc01"
  }
}

resource "aws_internet_gateway" "chrisbarm_igw01" {
  vpc_id = aws_vpc.chrisbarm_vpc01.id

  tags = {
    Name = "${local.name_prefix}-igw01"
  }
}

############################################
# Subnets (Public + Private)
############################################
resource "aws_subnet" "chrisbarm_public_subnets" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.chrisbarm_vpc01.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.name_prefix}-public-subnet0${count.index + 1}"
  }
}

resource "aws_subnet" "chrisbarm_private_subnets" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.chrisbarm_vpc01.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  tags = {
    Name = "${local.name_prefix}-private-subnet0${count.index + 1}"
  }
}

############################################
# Route Tables (Public has IGW route; Private intentionally has no 0.0.0.0/0 route)
############################################
resource "aws_route_table" "chrisbarm_public_rt01" {
  vpc_id = aws_vpc.chrisbarm_vpc01.id

  tags = {
    Name = "${local.name_prefix}-public-rt01"
  }
}

resource "aws_route" "chrisbarm_public_default_route01" {
  route_table_id         = aws_route_table.chrisbarm_public_rt01.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.chrisbarm_igw01.id
}

resource "aws_route_table_association" "chrisbarm_public_rta01" {
  count          = length(aws_subnet.chrisbarm_public_subnets)
  subnet_id      = aws_subnet.chrisbarm_public_subnets[count.index].id
  route_table_id = aws_route_table.chrisbarm_public_rt01.id
}

resource "aws_route_table" "chrisbarm_private_rt01" {
  vpc_id = aws_vpc.chrisbarm_vpc01.id

  tags = {
    Name = "${local.name_prefix}-private-rt01"
  }
}

resource "aws_route_table_association" "chrisbarm_private_rta01" {
  count          = length(aws_subnet.chrisbarm_private_subnets)
  subnet_id      = aws_subnet.chrisbarm_private_subnets[count.index].id
  route_table_id = aws_route_table.chrisbarm_private_rt01.id
}

############################################
# Security Groups: EC2 + RDS
############################################
resource "aws_security_group" "chrisbarm_ec2_sg01" {
  name        = "sg-ec2-lab"
  description = "EC2 app SG (HTTP in; egress all)"
  vpc_id      = aws_vpc.chrisbarm_vpc01.id

  tags = {
    Name = "sg-ec2-lab"
  }
}

resource "aws_vpc_security_group_ingress_rule" "chrisbarm_ec2_http_in01" {
  security_group_id = aws_security_group.chrisbarm_ec2_sg01.id
  ip_protocol       = local.tcp_protocol
  from_port         = local.ports_http
  to_port           = local.ports_http
  cidr_ipv4         = local.all_ipv4
}

# SSH intentionally not opened by default (SSM Session Manager is recommended)
# If your instructor requires SSH, add a tightly-scoped /32 rule here.

resource "aws_vpc_security_group_egress_rule" "chrisbarm_ec2_all_out01" {
  security_group_id = aws_security_group.chrisbarm_ec2_sg01.id
  ip_protocol       = "-1"
  from_port         = 0
  to_port           = 0
  cidr_ipv4         = local.all_ipv4
}

resource "aws_security_group" "chrisbarm_rds_sg01" {
  name        = "chrisbarm_rds_sg01"
  description = "RDS SG (MySQL only from EC2 SG)"
  vpc_id      = aws_vpc.chrisbarm_vpc01.id

  tags = {
    Name = "sg-rds-lab"
  }
}

resource "aws_vpc_security_group_ingress_rule" "chrisbarm_rds_mysql_from_ec2_01" {
  security_group_id            = aws_security_group.chrisbarm_rds_sg01.id
  ip_protocol                  = local.tcp_protocol
  from_port                    = local.db_port
  to_port                      = local.db_port
  referenced_security_group_id = aws_security_group.chrisbarm_ec2_sg01.id
}

resource "aws_vpc_security_group_egress_rule" "chrisbarm_rds_all_out01" {
  security_group_id = aws_security_group.chrisbarm_rds_sg01.id
  ip_protocol       = "-1"
  from_port         = 0
  to_port           = 0
  cidr_ipv4         = local.all_ipv4
}

############################################
# RDS: Subnet Group + MySQL Instance (Private)
############################################
resource "aws_db_subnet_group" "chrisbarm_db_subnet_group01" {
  name       = "${local.name_prefix}-db-subnet-group01"
  subnet_ids = aws_subnet.chrisbarm_private_subnets[*].id

  tags = {
    Name = "${local.name_prefix}-db-subnet-group01"
  }
}

resource "aws_db_instance" "chrisbarm_rds01" {
  identifier              = "lab-mysql"
  engine                  = var.db_engine
  instance_class          = var.db_instance_class
  allocated_storage       = 20
  storage_type            = var.storage_type
  db_name                 = var.db_name
  username                = var.db_username
  password                = var.db_password
  port                    = local.db_port
  db_subnet_group_name    = aws_db_subnet_group.chrisbarm_db_subnet_group01.name
  vpc_security_group_ids  = [aws_security_group.chrisbarm_rds_sg01.id]
  publicly_accessible     = false
  multi_az                = false
  backup_retention_period = 0
  skip_final_snapshot     = true
  deletion_protection     = false
  apply_immediately       = true

  tags = {
    Name = "lab-mysql"
  }
}

############################################
# Secrets Manager: Store DB Credentials (lab/rds/mysql)
############################################
resource "aws_secretsmanager_secret" "chrisbarm_db_secret01" {
  name                    = "lab/rds/mysql"
  recovery_window_in_days = 0

  tags = {
    Name = "${local.name_prefix}-lab-rds-mysql"
  }
}

resource "aws_secretsmanager_secret_version" "chrisbarm_db_secret_version01" {
  secret_id = aws_secretsmanager_secret.chrisbarm_db_secret01.id

  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    host     = aws_db_instance.chrisbarm_rds01.address
    port     = aws_db_instance.chrisbarm_rds01.port
    dbname   = var.db_name
  })

  depends_on = [aws_db_instance.chrisbarm_rds01]
}

############################################
# IAM: EC2 Role + Instance Profile (SSM + SecretsManager read)
############################################
resource "aws_iam_role" "chrisbarm_ec2_role01" {
  name = "${local.name_prefix}-ec2-role01"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_instance_profile" "chrisbarm_instance_profile01" {
  name = "${local.name_prefix}-instance-profile01"
  role = aws_iam_role.chrisbarm_ec2_role01.name
}

resource "aws_iam_policy" "chrisbarm_secrets_policy" {
  name        = "${local.name_prefix}-secrets-policy"
  description = "Allow EC2 to read ONLY the lab DB secret"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadLabDbSecret"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = aws_secretsmanager_secret.chrisbarm_db_secret01.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "chrisbarm_ec2_ssm_attach" {
  role       = aws_iam_role.chrisbarm_ec2_role01.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "chrisbarm_ec2_secrets_attach" {
  role       = aws_iam_role.chrisbarm_ec2_role01.name
  policy_arn = aws_iam_policy.chrisbarm_secrets_policy.arn
}

############################################
# EC2: App Host (public HTTP)
############################################
resource "aws_instance" "chrisbarm_ec2_app01" {
  ami                         = var.ec2_ami_id
  instance_type               = var.ec2_instance_type
  subnet_id                   = aws_subnet.chrisbarm_public_subnets[0].id
  vpc_security_group_ids      = [aws_security_group.chrisbarm_ec2_sg01.id]
  iam_instance_profile        = aws_iam_instance_profile.chrisbarm_instance_profile01.name
  associate_public_ip_address = true

  # Optional SSH key (SSH ingress is still not opened unless you add the rule above)
  key_name = (var.key_name != null && trim(var.key_name) != "") ? var.key_name : null

  metadata_options {
    http_tokens = "required" # IMDSv2
  }

  user_data_replace_on_change = true
  user_data = <<-EOF
    #!/bin/bash
    set -euo pipefail
}
    yum update -y
    yum install -y amazon-linux-extras
    amazon-linux-extras enable php8.0
    yum clean metadata
    yum install -y php php-mysqlnd httpd git

    systemctl enable httpd
    systemctl start httpd

    # Install AWS CLI v2
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
    unzip /tmp/awscliv2.zip -d /tmp
    /tmp/aws/install

    # Fetch DB credentials from Secrets Manager
    SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id lab/rds/mysql --query SecretString --output text --region ${var.aws_region})
    DB_USERNAME=$(echo $SECRET_JSON | jq -r .username)
    DB_PASSWORD=$(echo $SECRET_JSON | jq -r .password)
    DB_HOST=$(echo $SECRET_JSON | jq -r .host)
    DB_NAME=$(echo $SECRET_JSON | jq -r .dbname)

    # Create a simple PHP app that connects to RDS
    cat <<EOPHP > /var/www/html/index.php
    <?php
    \$servername = "${DB_HOST}";
    \$username = "${DB_USERNAME}";
    \$password = "${DB_PASSWORD}";
    \$dbname = "${DB_NAME}";

    // Create connection
    \$conn = new mysqli(\$servername, \$username, \$password, \$dbname);

    // Check connection
    if (\$conn->connect_error) {
        die("Connection failed: " . \$conn->connect_error);
    }
    echo "Connected successfully to the database!";
    ?>
    EOPHP

  EOF

  tags = {
    Name = "${local.name_prefix}-ec2-app01"
  }
}
