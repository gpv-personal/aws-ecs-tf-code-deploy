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

variable "services" {
  description = "Map of ECS services to run; each entry creates one ECS service and one one-container task definition"
  type = map(object({
    image                = string
    container_port       = number
    container_name       = optional(string)
    desired_count        = optional(number)
    task_cpu             = optional(number)
    task_memory          = optional(number)
    health_check_path    = optional(string)
    health_check_matcher = optional(string)
    path_pattern         = optional(string)
    host_headers         = optional(list(string))
    listener_priority    = optional(number)
  }))
  default = {}
}

variable "health_check_path" {
  description = "HTTP path used by the ALB target group health check"
  type        = string
  default     = "/"
}

variable "health_check_matcher" {
  description = "Expected HTTP status codes for healthy target responses"
  type        = string
  default     = "200-399"
}

variable "health_check_grace_period_seconds" {
  description = "Seconds to ignore failing health checks while a new ECS task starts"
  type        = number
  default     = 180
}

variable "codestar_connection_arn" {
  description = "Existing CodeStar connection ARN for CodePipeline source. Leave empty to create one in Terraform."
  type        = string
  default     = ""
}

variable "codestar_connection_name" {
  description = "Name for the CodeStar connection created by Terraform when codestar_connection_arn is empty"
  type        = string
  default     = "warwick-github-connection"
}

variable "repo_owner" {
  description = "GitHub owner or organization for CodePipeline source"
  type        = string
  default     = "gpv-personal"
}

variable "repo_name" {
  description = "GitHub repository name for CodePipeline source"
  type        = string
  default     = "aws-ecs-tf-code-deploy"
}

variable "repo_branch" {
  description = "GitHub branch for CodePipeline source"
  type        = string
  default     = "main"
}

variable "codebuild_compute_type" {
  description = "CodeBuild compute type for Terraform runs"
  type        = string
  default     = "BUILD_GENERAL1_SMALL"
}

variable "codebuild_image" {
  description = "Docker image for CodeBuild environment"
  type        = string
  default     = "aws/codebuild/standard:7.0"
}

variable "terraform_state_key" {
  description = "Object key used by the pipeline to persist Terraform state in S3"
  type        = string
  default     = "terraform/terraform.tfstate"
}
