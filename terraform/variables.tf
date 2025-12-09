variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
  default     = "683031685817"
}

variable "vpc_id" {
  description = "Existing VPC ID"
  type        = string
  default     = "vpc-04440292fc58c6a74"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "ecommerce-poc-eks"
}

variable "subnet_ids" {
  description = "Public subnet IDs for EKS"
  type        = list(string)
  default = [
    "subnet-033dfb4d5f93cfea1", # ap-southeast-1a
    "subnet-0a4eba8f84c7b50d2", # ap-southeast-1b
    "subnet-0a913be6b8f4e0b9f"  # ap-southeast-1c
  ]
}

variable "namespace" {
  description = "Kubernetes namespace for applications"
  type        = string
  default     = "ecommerce-poc"
}

# EC2 Node Group Configuration
variable "node_instance_types" {
  description = "EC2 instance types for node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "Desired number of nodes"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of nodes"
  type        = number
  default     = 3
}
