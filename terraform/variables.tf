variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
}

variable "project_name" {
  description = "Project name used for resource naming/tagging"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "availability_zones" {
  description = "AZs to spread subnets across"
  type        = list(string)
}

variable "eks_cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
}

variable "eks_node_instance_types" {
  description = "Instance types for the EKS managed node group"
  type        = list(string)
}

variable "eks_node_desired_size" {
  type = number
}

variable "eks_node_min_size" {
  type = number
}

variable "eks_node_max_size" {
  type = number
}
