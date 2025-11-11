terraform {
  required_version = ">= 1.13.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {}
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.common_tags
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # Use first 2 AZs for the demo
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)

  # Extract ALB ARN suffix for CloudWatch alarms
  alb_arn_suffix = module.ecs.alb_arn != null ? split("/", module.ecs.alb_arn)[1] : ""

  # Construct ECR image URL if container_image is not provided
  ecr_repository = "aws-platform-demo"
  container_image = var.container_image != "" ? var.container_image : "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${local.ecr_repository}:latest"
}

# KMS Key for encryption at rest
module "kms" {
  source = "./modules/kms"

  key_name    = "${var.project_name}-encryption-key"
  description = "KMS key for encrypting S3, CloudWatch Logs, and SNS"

  service_principals = [
    "s3.amazonaws.com",
    "logs.amazonaws.com",
    "sns.amazonaws.com"
  ]

  tags = var.common_tags
}

# VPC and Networking
module "vpc" {
  source = "./modules/vpc"

  project_name       = var.project_name
  vpc_cidr           = var.vpc_cidr
  availability_zones = local.availability_zones
  tags               = var.common_tags
}

# S3 Bucket with encryption and versioning
module "s3" {
  source = "./modules/s3"

  bucket_name      = "${var.project_name}-${var.environment}-bucket-${data.aws_caller_identity.current.account_id}"
  kms_key_arn      = module.kms.key_arn
  enable_lifecycle = true
  tags             = var.common_tags
}

# ECS Fargate Service
module "ecs" {
  source = "./modules/ecs"

  cluster_name   = "${var.project_name}-cluster"
  service_name   = "${var.project_name}-service"
  container_name = var.container_name
  container_image = local.container_image
  container_port = var.container_port

  task_cpu    = var.task_cpu
  task_memory = var.task_memory

  desired_count = var.desired_count
  vpc_id        = module.vpc.vpc_id
  subnet_ids    = module.vpc.public_subnet_ids

  kms_key_arn    = module.kms.key_arn
  s3_bucket_arn  = module.s3.bucket_arn

  enable_autoscaling  = var.enable_autoscaling
  min_capacity        = var.min_capacity
  max_capacity        = var.max_capacity
  cpu_target_value    = var.cpu_target_value
  memory_target_value = var.memory_target_value

  log_retention_days = var.log_retention_days

  environment_variables = [
    {
      name  = "ENVIRONMENT"
      value = var.environment
    },
    {
      name  = "S3_BUCKET"
      value = module.s3.bucket_id
    }
  ]

  tags = var.common_tags
}

# CloudWatch Alarms Module
module "cloudwatch_alarms" {
  source = "./modules/cloudwatch-alarm"

  alarm_prefix    = var.project_name
  sns_topic_name  = "${var.project_name}-alerts"
  email_addresses = var.alarm_email_addresses
  kms_key_id      = module.kms.key_id

  ecs_cluster_name = module.ecs.cluster_name
  ecs_service_name = module.ecs.service_name

  create_cpu_alarm    = true
  cpu_threshold       = 80
  cpu_period          = 300

  create_memory_alarm = true
  memory_threshold    = 80
  memory_period       = 300

  create_log_metric_filter = true
  log_group_name           = module.ecs.log_group_name
  log_filter_pattern       = "ERROR"
  log_threshold            = 10
  log_period               = 60

  create_alb_alarm = true
  alb_arn_suffix   = local.alb_arn_suffix

  tags = var.common_tags
}

data "aws_caller_identity" "current" {}
