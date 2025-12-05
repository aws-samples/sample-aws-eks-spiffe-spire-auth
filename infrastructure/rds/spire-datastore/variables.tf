variable "private_subnets" {
  description = "List of private subnet IDs"
  type        = list(string)
  default     = ["subnet-0a1b2c3d4e5f6a7b8", "subnet-0b2c3d4e5f6a7b8c9", "subnet-0c3d4e5f6a7b8c9d0"]
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