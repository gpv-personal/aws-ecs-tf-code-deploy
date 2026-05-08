# Terraform ECS Infrastructure on AWS

This project provisions the underlying infrastructure to run containerized applications on Amazon ECS with EC2 capacity (Auto Scaling Group + ECS capacity provider). It keeps application image build concerns out of scope and is intended to be applied by Terraform locally or from an external runner such as HCP Terraform.

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

## Prerequisites

- Terraform >= 1.5
- AWS account and credentials configured
- Permissions to create VPC, ECS, ELB, IAM, and CloudWatch resources

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

When using HCP Terraform, configure your workspace variables (matching the Terraform inputs in this repo) and connect the workspace to this repository/branch in HCP.

## Variables

- `services` configures one or more ECS services. Each service defines its own image, container port, desired count, health check settings, and ALB routing using `path_pattern` or `host_headers`.
- Legacy single-service variables (`container_image`, `container_port`, `desired_count`, `task_cpu`, `task_memory`) are still supported when `services` is empty.
- `ecs_instance_type`, `ecs_asg_min_size`, `ecs_asg_max_size`, and `ecs_asg_desired_capacity` configure ECS EC2 capacity.
- `ecs_capacity_provider_target_capacity` controls ECS managed scaling target utilization for the ASG capacity provider.

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
