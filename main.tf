data "aws_availability_zones" "available" {
  state = "available"
}

moved {
  from = aws_lb_target_group.blue
  to   = aws_lb_target_group.this["app"]
}

moved {
  from = aws_ecs_task_definition.this
  to   = aws_ecs_task_definition.this["app"]
}

moved {
  from = aws_ecs_service.this
  to   = aws_ecs_service.this["app"]
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  # ALB requires at least two subnets in different AZs.
  azs         = slice(data.aws_availability_zones.available.names, 0, 2)

  public_subnet_cidrs = [for i in range(length(local.azs)) : cidrsubnet(var.vpc_cidr, 4, i)]

  public_subnets = zipmap(local.azs, local.public_subnet_cidrs)

  repo_full_name = "${var.repo_owner}/${var.repo_name}"

  legacy_services = {
    app = {
      container_name       = "app"
      image                = var.container_image
      container_port       = var.container_port
      desired_count        = var.desired_count
      task_cpu             = var.task_cpu
      task_memory          = var.task_memory
      health_check_path    = var.health_check_path
      health_check_matcher = var.health_check_matcher
      path_pattern         = "/*"
      host_headers         = null
      listener_priority    = 100
    }
  }

  input_services = length(var.services) > 0 ? var.services : local.legacy_services

  service_definitions = {
    for service_name, service in local.input_services : service_name => {
      container_name       = coalesce(try(service.container_name, null), service_name)
      image                = service.image
      container_port       = service.container_port
      desired_count        = coalesce(try(service.desired_count, null), var.desired_count)
      task_cpu             = coalesce(try(service.task_cpu, null), var.task_cpu)
      task_memory          = coalesce(try(service.task_memory, null), var.task_memory)
      health_check_path    = coalesce(try(service.health_check_path, null), var.health_check_path)
      health_check_matcher = coalesce(try(service.health_check_matcher, null), var.health_check_matcher)
      host_headers         = try(service.host_headers, null)
      path_pattern         = try(service.path_pattern, null) != null ? try(service.path_pattern, null) : (try(service.host_headers, null) != null ? null : (service_name == "app" ? "/*" : "/${service_name}*"))
      listener_priority    = coalesce(try(service.listener_priority, null), 100 + index(sort(keys(local.input_services)), service_name))
    }
  }

  primary_service_name = sort(keys(local.service_definitions))[0]
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.name_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.name_prefix}-igw"
  }
}

resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = each.value
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.name_prefix}-public-${each.key}"
    Tier = "public"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${local.name_prefix}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-alb-sg"
  }
}

resource "aws_security_group" "ecs_instances" {
  name        = "${local.name_prefix}-ecs-instance-sg"
  description = "Security group for ECS container instances"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "Allow ALB traffic"
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-ecs-instance-sg"
  }
}

resource "aws_lb" "this" {
  name               = substr(replace("${local.name_prefix}-alb", "_", "-"), 0, 32)
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [for subnet in aws_subnet.public : subnet.id]

  tags = {
    Name = "${local.name_prefix}-alb"
  }
}

resource "aws_lb_target_group" "this" {
  for_each    = local.service_definitions
  name        = substr(replace("${local.name_prefix}-${each.key}", "_", "-"), 0, 32)
  port        = each.value.container_port
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.this.id

  lifecycle {
    create_before_destroy = true
  }

  health_check {
    path                = each.value.health_check_path
    matcher             = each.value.health_check_matcher
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 5
    interval            = 30
  }

  tags = {
    Name = "${local.name_prefix}-${each.key}"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[local.primary_service_name].arn
  }
}

resource "aws_lb_listener_rule" "service" {
  for_each     = { for service_name, service in local.service_definitions : service_name => service if service_name != local.primary_service_name }
  listener_arn = aws_lb_listener.http.arn
  priority     = each.value.listener_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[each.key].arn
  }

  dynamic "condition" {
    for_each = each.value.path_pattern != null ? [1] : []

    content {
      path_pattern {
        values = [each.value.path_pattern]
      }
    }
  }

  dynamic "condition" {
    for_each = each.value.host_headers != null ? [1] : []

    content {
      host_header {
        values = each.value.host_headers
      }
    }
  }
}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${local.name_prefix}"
  retention_in_days = 30
}

resource "aws_iam_role" "ecs_task_execution" {
  name = "${local.name_prefix}-ecs-task-exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task" {
  name = "${local.name_prefix}-ecs-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role" "ecs_instance" {
  name = "${local.name_prefix}-ecs-instance"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_instance" {
  role       = aws_iam_role.ecs_instance.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_instance" {
  name = "${local.name_prefix}-ecs-instance-profile"
  role = aws_iam_role.ecs_instance.name
}

data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

resource "aws_launch_template" "ecs" {
  name_prefix   = "${local.name_prefix}-ecs-"
  image_id      = data.aws_ssm_parameter.ecs_ami.value
  instance_type = var.ecs_instance_type

  iam_instance_profile {
    arn = aws_iam_instance_profile.ecs_instance.arn
  }

  vpc_security_group_ids = [aws_security_group.ecs_instances.id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo ECS_CLUSTER=${aws_ecs_cluster.this.name} >> /etc/ecs/ecs.config
  EOF
  )
}

resource "aws_autoscaling_group" "ecs" {
  name                = "${local.name_prefix}-ecs-asg"
  min_size            = var.ecs_asg_min_size
  max_size            = var.ecs_asg_max_size
  desired_capacity    = var.ecs_asg_desired_capacity
  vpc_zone_identifier = [for subnet in aws_subnet.public : subnet.id]
  health_check_type   = "EC2"

  launch_template {
    id      = aws_launch_template.ecs.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${local.name_prefix}-ecs-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = "true"
    propagate_at_launch = true
  }
}

resource "aws_ecs_capacity_provider" "this" {
  name = "cp-${local.name_prefix}"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.ecs.arn

    managed_scaling {
      status                    = "ENABLED"
      target_capacity           = var.ecs_capacity_provider_target_capacity
      minimum_scaling_step_size = 1
      maximum_scaling_step_size = 4
    }

    managed_termination_protection = "DISABLED"
  }
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = [aws_ecs_capacity_provider.this.name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.this.name
    weight            = 1
    base              = 1
  }
}

resource "aws_ecs_cluster" "this" {
  name = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_task_definition" "this" {
  for_each                 = local.service_definitions
  family                   = substr(replace("${local.name_prefix}-${each.key}-task", "_", "-"), 0, 255)
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = each.value.container_name
      image     = each.value.image
      essential = true
      memory    = each.value.task_memory
      cpu       = each.value.task_cpu
      portMappings = [
        {
          containerPort = each.value.container_port
          hostPort      = 0
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "this" {
  for_each        = local.service_definitions
  name            = "${local.name_prefix}-${each.key}-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this[each.key].arn
  desired_count   = each.value.desired_count
  health_check_grace_period_seconds = var.health_check_grace_period_seconds

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.this.name
    weight            = 1
    base              = 1
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this[each.key].arn
    container_name   = each.value.container_name
    container_port   = each.value.container_port
  }

  depends_on = [aws_lb_listener.http, aws_ecs_cluster_capacity_providers.this]
}

resource "aws_codestarconnections_connection" "github" {
  count         = var.codestar_connection_arn == "" ? 1 : 0
  name          = var.codestar_connection_name
  provider_type = "GitHub"
}

locals {
  source_connection_arn = var.codestar_connection_arn != "" ? var.codestar_connection_arn : aws_codestarconnections_connection.github[0].arn
}

resource "aws_s3_bucket" "pipeline_artifacts" {
  bucket_prefix = "${local.name_prefix}-pipeline-artifacts-"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "pipeline_artifacts" {
  bucket = aws_s3_bucket.pipeline_artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "pipeline_artifacts" {
  bucket = aws_s3_bucket.pipeline_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket" "terraform_state" {
  bucket_prefix = "${local.name_prefix}-tfstate-"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_iam_role" "codebuild" {
  name = "${local.name_prefix}-codebuild"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "codebuild" {
  name = "${local.name_prefix}-codebuild-policy"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:GetBucketAcl",
          "s3:GetBucketLocation",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.pipeline_artifacts.arn,
          "${aws_s3_bucket.pipeline_artifacts.arn}/*",
          aws_s3_bucket.terraform_state.arn,
          "${aws_s3_bucket.terraform_state.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = "*"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "codepipeline" {
  name = "${local.name_prefix}-codepipeline"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "codepipeline" {
  name = "${local.name_prefix}-codepipeline-policy"
  role = aws_iam_role.codepipeline.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketVersioning",
          "s3:PutObjectAcl",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.pipeline_artifacts.arn,
          "${aws_s3_bucket.pipeline_artifacts.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "codestar-connections:UseConnection"
        ]
        Resource = local.source_connection_arn
      },
      {
        Effect = "Allow"
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild"
        ]
        Resource = aws_codebuild_project.terraform.arn
      }
    ]
  })
}

resource "aws_codebuild_project" "terraform" {
  name         = "${local.name_prefix}-terraform"
  service_role = aws_iam_role.codebuild.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = var.codebuild_compute_type
    image                       = var.codebuild_image
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }

    environment_variable {
      name  = "TF_STATE_BUCKET"
      value = aws_s3_bucket.terraform_state.bucket
    }

    environment_variable {
      name  = "TF_STATE_KEY"
      value = var.terraform_state_key
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec-infra.yml"
  }

  logs_config {
    cloudwatch_logs {
      group_name = "/aws/codebuild/${local.name_prefix}-terraform"
    }
  }
}

resource "aws_codepipeline" "terraform" {
  name     = "${local.name_prefix}-pipeline"
  role_arn = aws_iam_role.codepipeline.arn

  artifact_store {
    location = aws_s3_bucket.pipeline_artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["SourceArtifact"]

      configuration = {
        ConnectionArn        = local.source_connection_arn
        FullRepositoryId     = local.repo_full_name
        BranchName           = var.repo_branch
        OutputArtifactFormat = "CODE_ZIP"
      }
    }
  }

  stage {
    name = "DeployInfra"

    action {
      name            = "TerraformApply"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["SourceArtifact"]

      configuration = {
        ProjectName = aws_codebuild_project.terraform.name
      }
    }
  }

  depends_on = [
    aws_iam_role_policy.codepipeline,
    aws_iam_role_policy.codebuild
  ]
}
