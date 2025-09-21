variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-3"
}

variable "vpc_id" {
  description = "Existing VPC ID"
  type        = string
  default     = "vpc-00ffe463659a905fd"
}

variable "internet_gateway_id" {
  description = "Internet Gateway ID attached to the VPC"
  type        = string
  default     = "igw-0ab67e09d24810be0"
}

variable "subnet_cidr_block" {
  description = "Public subnet CIDR to create"
  type        = string
  default     = "10.0.3.0/24"
}

variable "availability_zone" {
  description = "Availability Zone for the subnet"
  type        = string
  default     = "ap-northeast-3a"
}

variable "key_name" {
  description = "Name for the EC2 key pair"
  type        = string
  default     = "oiseoje-lab-key"
}

variable "public_key_path" {
  description = "Path to your SSH public key"
  type        = string
  default     = "~/.ssh/lab_deploy.pub"
}

variable "web_port" {
  description = "Port Nginx will listen on"
  type        = number
  default     = 8080
}

variable "deploy_user" {
  description = "Linux user for CI/CD SSH"
  type        = string
  default     = "ubuntu"
}
