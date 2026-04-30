# Terraform ECS + CI/CD on AWS

This project provisions a complete baseline to run a containerized application on **Amazon ECS (Fargate)**, with deployments managed by **AWS CodeDeploy (blue/green)** and a full CI/CD path through **CodePipeline + CodeBuild**.

## What it creates

- VPC with public subnets across two Availability Zones
- Public subnets for ALB and ECS tasks
- Internet Gateway
- Application Load Balancer + blue/green target groups + prod/test HTTP listeners
- ECS cluster with Container Insights enabled
- ECS task definition and ECS service (Fargate, `CODE_DEPLOY` controller)
- IAM execution role and task role
- CodeDeploy application + deployment group + IAM role
- ECR repository for application images
- CodeBuild project to build Docker image, push to ECR, and generate deployment artifacts
- CodePipeline with Source (GitHub via CodeStar connection), Build, and Deploy (CodeDeployToECS) stages
- S3 artifact bucket for CodePipeline
- CloudWatch log group for container logs

## Prerequisites

- Terraform >= 1.5
- AWS account and credentials configured (for example via `aws configure`)
- Permissions to create VPC, ECS, ELB, IAM, CloudWatch, CodeBuild, CodePipeline, ECR, S3, and CodeStar connections

## Usage

1. Copy and customize variables:

   ```bash
   copy terraform.tfvars.example terraform.tfvars
   ```

2. Initialize Terraform:

   ```bash
   terraform init
   ```

3. Review plan:

   ```bash
   terraform plan
   ```

4. Apply:

   ```bash
   terraform apply
   ```

5. If Terraform created the CodeStar connection (you left `codestar_connection_arn` empty), authorize it once in AWS Console:

   - Open Developer Tools > Settings > Connections
   - Find the connection output by Terraform
   - Complete the GitHub handshake (status must become `AVAILABLE`)

6. After apply, use the ALB output:

   ```bash
   terraform output alb_dns_name
   ```

7. Confirm deployment resources:

   ```bash
   terraform output codedeploy_app_name
   terraform output codedeploy_deployment_group_name
   terraform output ecr_repository_url
   terraform output codebuild_project_name
   terraform output codepipeline_name
   ```

8. Trigger a deployment by committing to the configured branch.

## Cleanup

```bash
terraform destroy
```

## Notes

- This starter exposes HTTP (port 80) publicly via the ALB.
- A second HTTP listener (default `8080`) is created for CodeDeploy test traffic.
- ECS tasks run in public subnets and are assigned public IPs.
- NAT gateways are not used in this sandbox configuration to reduce cost.
- `container_image` is used for initial bootstrap task definition. Subsequent deployments are performed by CodePipeline/CodeBuild/CodeDeploy.
- Source repository must contain a `Dockerfile` and `buildspec.yml` at the repository root.

## Pipeline Artifact Flow

CodeDeploy does not pull artifacts from GitHub directly. This stack uses:

1. Source stage pulls your repo through CodeStar connection.
2. Build stage (`buildspec.yml`) builds image and pushes to ECR.
3. Build stage generates `taskdef.json`, `appspec.yaml`, and `imageDetail.json` artifacts.
4. Deploy stage uses `CodeDeployToECS` for blue/green ECS rollout.

An AppSpec example remains available at `deployment/appspec.yaml.example`.
