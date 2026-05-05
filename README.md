# Terraform ECS Infrastructure on AWS

This project provisions the underlying infrastructure to run containerized applications on Amazon ECS with EC2 capacity (Auto Scaling Group + ECS capacity provider). It keeps application image build concerns out of scope, but includes a CodePipeline workflow to deploy infrastructure changes through Terraform.

## What it creates

- VPC with public subnets across two Availability Zones
- Internet Gateway and public route table
- Application Load Balancer with a single HTTP listener
- ECS cluster with Container Insights enabled
- ECS capacity provider backed by an EC2 Auto Scaling Group
- One ECS task definition and one ECS service per configured service (one container per service)
- IAM task execution role and task role
- IAM role and instance profile for ECS EC2 instances
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

   The pipeline now fails fast when this state object is missing to prevent accidental recreation of existing resources.
   Pipeline runs also upload Terraform state in a build finally step so partial applies are persisted when possible.

7. If Terraform created the CodeStar connection (you left `codestar_connection_arn` empty), authorize it once in AWS Console:

   - Open Developer Tools > Settings > Connections
   - Find the connection output by Terraform
   - Complete the GitHub handshake (status must become `AVAILABLE`)

8. Trigger pipeline deployment by committing to the configured branch.

## Variables

- `services` configures one or more ECS services. Each service defines its own image, container port, desired count, health check settings, and ALB routing using `path_pattern` or `host_headers`.
- Legacy single-service variables (`container_image`, `container_port`, `desired_count`, `task_cpu`, `task_memory`) are still supported when `services` is empty.
- `ecs_instance_type`, `ecs_asg_min_size`, `ecs_asg_max_size`, and `ecs_asg_desired_capacity` configure ECS EC2 capacity.
- `ecs_capacity_provider_target_capacity` controls ECS managed scaling target utilization for the ASG capacity provider.
- `repo_owner`, `repo_name`, and `repo_branch` configure the pipeline source.
- `terraform_state_key` sets where pipeline Terraform state is stored in S3.

### Changing images via CodePipeline

CodePipeline does not use `terraform.tfvars` because that file is git-ignored.

To change deployed images for pipeline runs:

1. Update the `services` map in `terraform.pipeline.tfvars`.
2. Commit and push the change.
3. Run/release the pipeline.

`buildspec-infra.yml` passes `-var-file=terraform.pipeline.tfvars` to Terraform plan/apply, so the image now comes from source control.

### Multiple services routing

- One service is selected as the default ALB route.
- Additional services are routed with listener rules using each service `listener_priority` plus either `path_pattern` or `host_headers`.
- Path-based example: set `api` to `/api*`.
- Host-based example: set `api` `host_headers` to `api.localtest.me`.
- Use each service `container_port` for the port the container actually listens on (often `80` even when routed by `/api*` or `/copy*`).
- Target group health checks run directly against the task IP and service port, not through ALB path-based routing rules.

To test host-based routing with an ALB DNS name:

1. Get ALB DNS from `terraform output alb_dns_name`.
2. Send a request with the expected Host header.

   Example:

   `curl -H "Host: copy.localtest.me" http://<alb-dns-name>/`

## Cleanup

```bash
terraform destroy
```

## Notes

- This stack exposes HTTP on port 80 through the ALB.
- ECS tasks run on ECS EC2 container instances in public subnets.
- NAT gateways are not used in this sandbox configuration to reduce cost.
- The stack does not build or publish container images; supply reachable image references in `services` (or `container_image` for legacy single-service mode).
- The pipeline uses `buildspec-infra.yml` and executes Terraform apply from CodeBuild.
