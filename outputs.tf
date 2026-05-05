output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.this.id
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.this.name
}

output "ecs_service_name" {
  description = "Name of the primary ECS service (for backward compatibility)"
  value       = try(aws_ecs_service.this[local.primary_service_name].name, null)
}

output "ecs_service_names" {
  description = "Names of all ECS services"
  value       = { for service_name, service in aws_ecs_service.this : service_name => service.name }
}

output "alb_dns_name" {
  description = "DNS name of the application load balancer"
  value       = aws_lb.this.dns_name
}

output "ecs_asg_name" {
  description = "Auto Scaling Group name used by ECS capacity provider"
  value       = aws_autoscaling_group.ecs.name
}

output "ecs_capacity_provider_name" {
  description = "ECS capacity provider name backed by the Auto Scaling Group"
  value       = aws_ecs_capacity_provider.this.name
}

output "codebuild_project_name" {
  description = "CodeBuild project name used for Terraform deployment"
  value       = aws_codebuild_project.terraform.name
}

output "codepipeline_name" {
  description = "CodePipeline name for infrastructure deployment"
  value       = aws_codepipeline.terraform.name
}

output "codestar_connection_arn" {
  description = "CodeStar connection ARN used by CodePipeline source"
  value       = local.source_connection_arn
}

output "terraform_state_bucket_name" {
  description = "S3 bucket name used by pipeline-run Terraform state persistence"
  value       = aws_s3_bucket.terraform_state.bucket
}
