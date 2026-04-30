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

variable "codedeploy_test_listener_port" {
  description = "ALB listener port used by CodeDeploy for test traffic"
  type        = number
  default     = 8080
}

variable "codedeploy_deployment_config_name" {
  description = "CodeDeploy ECS deployment config"
  type        = string
  default     = "CodeDeployDefault.ECSAllAtOnce"
}

variable "ecr_repository_name" {
  description = "ECR repository name used by CodeBuild for container images"
  type        = string
  default     = "warwick/images"
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
}

variable "repo_name" {
  description = "GitHub repository name for CodePipeline source"
  type        = string
}

variable "repo_branch" {
  description = "GitHub branch for CodePipeline source"
  type        = string
  default     = "main"
}

variable "codebuild_compute_type" {
  description = "CodeBuild compute type"
  type        = string
  default     = "BUILD_GENERAL1_SMALL"
}

variable "codebuild_image" {
  description = "Docker image for CodeBuild environment"
  type        = string
  default     = "aws/codebuild/standard:7.0"
}
