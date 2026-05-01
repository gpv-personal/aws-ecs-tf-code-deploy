# Terraform ECS Infrastructure on AWS

This project provisions the underlying infrastructure to run a containerized application on Amazon ECS Fargate. It is intentionally focused on the runtime platform rather than image build or deployment automation.

## What it creates

- VPC with public subnets across two Availability Zones
- Internet Gateway and public route table
- Application Load Balancer with a single HTTP listener
- ECS cluster with Container Insights enabled
- ECS task definition and ECS service on Fargate
- IAM task execution role and task role
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

## Variables

- `container_image` sets the image used by the ECS task definition.
- `container_port` sets the port exposed by the container and target group.
- `desired_count`, `task_cpu`, and `task_memory` control the Fargate service shape.

## Cleanup

```bash
terraform destroy
```

## Notes

- This stack exposes HTTP on port 80 through the ALB.
- ECS tasks run in public subnets and are assigned public IPs.
- NAT gateways are not used in this sandbox configuration to reduce cost.
- The stack does not build or publish container images; supply a reachable image reference via `container_image`.
