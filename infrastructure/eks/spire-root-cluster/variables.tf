variable "private_subnets" {
  description = "List of private subnet IDs"
  type        = list(string)
  default     = ["subnet-0a1b2c3d4e5f6a7b8", "subnet-0b2c3d4e5f6a7b8c9", "subnet-0c3d4e5f6a7b8c9d0"]
}

variable "private_subnets_cidr" {
  description = "List of CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.0.0/20", "10.0.16.0/20", "10.0.32.0/20"]
}

variable "public_subnets" {
  description = "List of public subnet IDs"
  type        = list(string)
  default     = ["subnet-0d4e5f6a7b8c9d0e1", "subnet-0e5f6a7b8c9d0e1f2", "subnet-0f6a7b8c9d0e1f2a3"]
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
  default     = "vpc-0a1b2c3d4e5f6a7b8"
}

variable "external_secrets_secrets_manager_arns" {
  description = "List of Secrets Manager ARNs for External Secrets"
  type        = list(string)
  default     = ["arn:aws:secretsmanager:us-east-1:111122223333:secret:rds!cluster-12345678-1234-1234-1234-123456789012-AbCdEf"]
}

variable "route53_zone_arns" {
  description = "List of Route53 hosted zone ARNs"
  type        = list(string)
  default     = ["arn:aws:route53:::hostedzone/Z00964391G7DEOMQW2LCA"]
}

variable "rds_cluster_arn" {
  description = "ARN of the RDS cluster for IAM database authentication"
  type        = string
  default     = "arn:aws:rds:us-east-1:111122223333:cluster:spire-datastore-mysqlv2"
}