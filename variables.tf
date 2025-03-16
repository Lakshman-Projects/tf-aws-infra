variable "aws_profile" {
  description = "AWS CLI Profile to use"
  type        = string
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "VPC CIDR Block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
  default     = "my-vpc"
}

variable "public_subnets" {
  description = "List of public subnets"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24", "10.0.5.0/24"]
}

variable "private_subnets" {
  description = "List of private subnets"
  type        = list(string)
  default     = ["10.0.7.0/24", "10.0.8.0/24", "10.0.9.0/24"]
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "allowed_ports" {
  description = "List of ports to allow for ingress"
  type        = list(number)
  default     = [22, 80, 443, 8080]
}

variable "custom_ami_id" {
  description = "The AMI ID for the custom EC2 instance"
  type        = string
}

variable "key_name" {
  description = "The key pair name to be used for SSH access"
  type        = string
}

variable "bucket_sse_algorithm" {
  description = "The server-side encryption algorithm to use for the S3 bucket"
  type        = string
  default     = "AES256"
}

variable "bucket_Transition_days" {
  description = "The number of days to retain the object in the bucket before transitioning to Standard_IA storage class"
  type        = number
  default     = 30
  
}

variable "db_port" {
  description = "The port for the RDS instance"
  type        = number
  default     = 5432
}

variable "db_family" {
  description = "The family of the DB parameter group"
  type        = string
  default     = "postgres17"
}

variable "db_username" {
  description = "The username for the RDS instance"
  type        = string
  default = "csye6225"
}

variable "db_password" {
  description = "The password for the RDS instance"
  type        = string  
}