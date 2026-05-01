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
