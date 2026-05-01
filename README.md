# Terraform ECS Infrastructure on AWS

This project provisions the underlying infrastructure to run a containerized application on Amazon ECS Fargate. It keeps application image build concerns out of scope, but includes a CodePipeline workflow to deploy infrastructure changes through Terraform.

## What it creates

- VPC with public subnets across two Availability Zones
- Internet Gateway and public route table
- Application Load Balancer with a single HTTP listener
- ECS cluster with Container Insights enabled
- ECS task definition and ECS service on Fargate
- IAM task execution role and task role
- CloudWatch log group for container logs
- CodeStar connection (or use an existing one) for GitHub source integration
- CodePipeline + CodeBuild workflow that runs Terraform validate/plan/apply
- S3 artifact bucket for CodePipeline
- S3 bucket for pipeline-managed Terraform state snapshots

## Prerequisites

- Terraform >= 1.5
- AWS account and credentials configured
- Permissions to create VPC, ECS, ELB, IAM, CloudWatch, CodeBuild, CodePipeline, CodeStar connections, and S3 resources

## Usage

1. Copy and customize variables:

   ```bash
   copy terraform.tfvars.example terraform.tfvars
   ```

2. Initialize Terraform:

   ```bash
   terraform init
   ```

3. Review the planned infrastructure:

   ```bash
   terraform plan
   ```

4. Apply the stack:

   ```bash
   terraform apply
   ```

5. Retrieve the load balancer endpoint:

   ```bash
   terraform output alb_dns_name
   ```

6. Capture the initial local state into the pipeline state bucket (one-time bootstrap after first manual apply):

   ```powershell
   $bucket = terraform output -raw terraform_state_bucket_name
   aws s3 cp terraform.tfstate "s3://$bucket/terraform/terraform.tfstate"
   ```

7. If Terraform created the CodeStar connection (you left `codestar_connection_arn` empty), authorize it once in AWS Console:

   - Open Developer Tools > Settings > Connections
   - Find the connection output by Terraform
   - Complete the GitHub handshake (status must become `AVAILABLE`)

8. Trigger pipeline deployment by committing to the configured branch.

## Variables

- `container_image` sets the image used by the ECS task definition.
- `container_port` sets the port exposed by the container and target group.
- `desired_count`, `task_cpu`, and `task_memory` control the Fargate service shape.
- `repo_owner`, `repo_name`, and `repo_branch` configure the pipeline source.
- `terraform_state_key` sets where pipeline Terraform state is stored in S3.

## Cleanup

```bash
terraform destroy
```

## Notes

- This stack exposes HTTP on port 80 through the ALB.
- ECS tasks run in public subnets and are assigned public IPs.
- NAT gateways are not used in this sandbox configuration to reduce cost.
- The stack does not build or publish container images; supply a reachable image reference via `container_image`.
- The pipeline uses `buildspec-infra.yml` and executes Terraform apply from CodeBuild.
