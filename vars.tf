variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "key_name_prefix" {
  description = "Prefix for generated key pair"
  type        = string
  default     = "devsecops_key"
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH (default: 0.0.0.0/0)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "instance_ami" {
  description = "AMI ID for Ubuntu (if set). If empty, the latest Ubuntu 22.04 LTS will be used"
  type        = string
  default     = ""
}

variable "agent_name" {
  description = "Name for the Ubuntu agent"
  type        = string
}

variable "jenkins_key_name" {
  description = "Name of the Jenkins SSH key"
  type        = string
}