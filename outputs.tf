output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.this.id
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.this.name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.this.name
}

output "alb_dns_name" {
  description = "DNS name of the application load balancer"
  value       = aws_lb.this.dns_name
}

output "codedeploy_app_name" {
  description = "CodeDeploy ECS application name"
  value       = aws_codedeploy_app.ecs.name
}

output "codedeploy_deployment_group_name" {
  description = "CodeDeploy deployment group name"
  value       = aws_codedeploy_deployment_group.ecs.deployment_group_name
}

output "ecr_repository_url" {
  description = "ECR repository URL used by CodeBuild"
  value       = aws_ecr_repository.app.repository_url
}

output "codebuild_project_name" {
  description = "CodeBuild project name"
  value       = aws_codebuild_project.this.name
}

output "codepipeline_name" {
  description = "CodePipeline name"
  value       = aws_codepipeline.this.name
}

output "codestar_connection_arn" {
  description = "CodeStar connection ARN used by CodePipeline source"
  value       = local.source_connection_arn
}
