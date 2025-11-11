# East US - Development Environment
# Region: us-east-1
# Environment: dev

aws_region   = "us-east-1"
project_name = "aws-platform-demo"
environment  = "dev"

# Container Configuration
# Leave empty to automatically use ECR image: <account-id>.dkr.ecr.us-east-1.amazonaws.com/aws-platform-demo:latest
container_image = ""

# ECS Configuration
desired_count = 2
task_cpu      = "256"
task_memory   = "512"

# Autoscaling
enable_autoscaling  = true
min_capacity        = 1
max_capacity        = 4
cpu_target_value    = 70
memory_target_value = 80

# CloudWatch Alarms - will be set by GitHub Actions secret
alarm_email_addresses = []  # Populated from GitHub secret ALARM_EMAIL

# Tags
common_tags = {
  Project     = "AWS Platform Demo"
  ManagedBy   = "Terraform"
  Environment = "dev"
  Region      = "us-east-1"
}
