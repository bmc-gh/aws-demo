resource "aws_sns_topic" "alarm" {
  name              = var.sns_topic_name
  kms_master_key_id = var.kms_key_id

  # Enable content-based message deduplication for FIFO (not applicable for standard)
  # fifo_topic = false

  # Enforce HTTPS for message delivery
  http_success_feedback_role_arn = null
  http_failure_feedback_role_arn = null

  # Enable message delivery status logging (optional)
  # application_success_feedback_role_arn = var.sns_feedback_role_arn
  # application_failure_feedback_role_arn = var.sns_feedback_role_arn

  tags = var.tags
}

# SNS Topic Policy - restrict who can publish
resource "aws_sns_topic_policy" "alarm" {
  arn = aws_sns_topic.alarm.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudWatchToPublish"
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.alarm.arn
      },
      {
        Sid    = "AllowAccountAccess"
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action = [
          "SNS:GetTopicAttributes",
          "SNS:SetTopicAttributes",
          "SNS:AddPermission",
          "SNS:RemovePermission",
          "SNS:DeleteTopic",
          "SNS:Subscribe",
          "SNS:ListSubscriptionsByTopic",
          "SNS:Publish"
        ]
        Resource = aws_sns_topic.alarm.arn
        Condition = {
          StringEquals = {
            "AWS:SourceOwner" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

data "aws_caller_identity" "current" {}

resource "aws_sns_topic_subscription" "alarm_email" {
  count     = length(var.email_addresses)
  topic_arn = aws_sns_topic.alarm.arn
  protocol  = "email"
  endpoint  = var.email_addresses[count.index]
}

resource "aws_cloudwatch_metric_alarm" "ecs_cpu" {
  count               = var.create_cpu_alarm ? 1 : 0
  alarm_name          = "${var.alarm_prefix}-ecs-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.cpu_evaluation_periods
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = var.cpu_period
  statistic           = "Average"
  threshold           = var.cpu_threshold
  alarm_description   = "This metric monitors ECS CPU utilization"
  alarm_actions       = [aws_sns_topic.alarm.arn]
  ok_actions          = [aws_sns_topic.alarm.arn]

  # Handle missing data - important for new services
  treat_missing_data = "notBreaching"

  # Require multiple consecutive breaches before alarming
  datapoints_to_alarm = var.cpu_evaluation_periods

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.ecs_service_name
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "ecs_memory" {
  count               = var.create_memory_alarm ? 1 : 0
  alarm_name          = "${var.alarm_prefix}-ecs-high-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.memory_evaluation_periods
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = var.memory_period
  statistic           = "Average"
  threshold           = var.memory_threshold
  alarm_description   = "This metric monitors ECS memory utilization"
  alarm_actions       = [aws_sns_topic.alarm.arn]
  ok_actions          = [aws_sns_topic.alarm.arn]

  # Handle missing data - important for new services
  treat_missing_data = "notBreaching"

  # Require multiple consecutive breaches before alarming
  datapoints_to_alarm = var.memory_evaluation_periods

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.ecs_service_name
  }

  tags = var.tags
}

resource "aws_cloudwatch_log_metric_filter" "error_log" {
  count          = var.create_log_metric_filter ? 1 : 0
  name           = "${var.alarm_prefix}-error-count"
  log_group_name = var.log_group_name
  pattern        = var.log_filter_pattern

  metric_transformation {
    name      = "${var.alarm_prefix}-ErrorCount"
    namespace = "CustomMetrics"
    value     = "1"
    default_value = 0
  }
}

resource "aws_cloudwatch_metric_alarm" "error_log" {
  count               = var.create_log_metric_filter ? 1 : 0
  alarm_name          = "${var.alarm_prefix}-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.log_evaluation_periods
  metric_name         = "${var.alarm_prefix}-ErrorCount"
  namespace           = "CustomMetrics"
  period              = var.log_period
  statistic           = "Sum"
  threshold           = var.log_threshold
  alarm_description   = "This metric monitors error log entries"
  alarm_actions       = [aws_sns_topic.alarm.arn]
  ok_actions          = [aws_sns_topic.alarm.arn]
  treat_missing_data  = "notBreaching"

  tags = var.tags

  depends_on = [aws_cloudwatch_log_metric_filter.error_log]
}

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_targets" {
  count               = var.create_alb_alarm ? 1 : 0
  alarm_name          = "${var.alarm_prefix}-alb-unhealthy-targets"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "Alert when there are unhealthy targets"
  alarm_actions       = [aws_sns_topic.alarm.arn]
  ok_actions          = [aws_sns_topic.alarm.arn]

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  tags = var.tags
}
