provider "aws" {
  region = local.region
}

locals {
  name = basename(path.cwd)
  region = "us-east-1"

  tags = {
    Blueprint  = local.name
    GithubRepo = "github.com/aws-samples/sample-aws-eks-spiffe-spire-auth"
  }
}

resource "aws_db_subnet_group" "main" {
  name       = "${local.name}-subnet-group"
  subnet_ids = var.private_subnets
  tags       = local.tags
}

module "aurora_mysql_v2" {
  source  = "terraform-aws-modules/rds-aurora/aws"
  version = "~> 9.16.0"

  name              = "${local.name}-mysqlv2"
  engine            = "aurora-mysql"
  engine_mode       = "provisioned"
  engine_version    = "8.0"
  storage_encrypted = true
  master_username   = "spireadmin"
  database_name     = "spireserver"

  enabled_cloudwatch_logs_exports = ["error"]

  vpc_id               = var.vpc_id
  db_subnet_group_name = aws_db_subnet_group.main.name

  security_group_rules = {
    vpc_ingress_10_0 = {
      cidr_blocks = ["10.0.0.0/16"]
    }
    all_outbound = {
      type        = "egress"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  monitoring_interval = 60
  apply_immediately   = true
  skip_final_snapshot = true

  serverlessv2_scaling_configuration = {
    min_capacity = 2
    max_capacity = 6
  }

  instance_class = "db.serverless"
  instances = {
    one = {}
    two = {}
  }

  tags = local.tags
}