variable "aws_region" {
  description = "AWS region to deploy resources into"
  type        = string
  default     = "eu-west-2"
}

variable "project_name" {
  description = "Project name used in resource naming"
  type        = string
  default     = "ecs-cluster"
}

variable "environment" {
  description = "Environment name (e.g. dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "container_image" {
  description = "Container image for the ECS task"
  type        = string
  default     = "public.ecr.aws/nginx/nginx:stable-alpine"
}

variable "container_port" {
  description = "Container port exposed by the service"
  type        = number
  default     = 80
}

variable "task_cpu" {
  description = "Task CPU units for Fargate"
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Task memory (MiB) for Fargate"
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 2
}
