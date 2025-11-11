run "verify_sns_topic_creation" {
  command = plan

  variables {
    alarm_prefix      = "test"
    sns_topic_name    = "test-alerts"
    email_addresses   = ["test@example.com"]
    ecs_cluster_name  = "test-cluster"
    ecs_service_name  = "test-service"
  }

  # Verify SNS topic is created
  assert {
    condition     = aws_sns_topic.alarm.name == var.sns_topic_name
    error_message = "SNS topic name should match the provided value"
  }

  # Verify email subscription is created
  assert {
    condition     = length(aws_sns_topic_subscription.alarm_email) == length(var.email_addresses)
    error_message = "Number of email subscriptions should match number of email addresses"
  }
}

run "verify_cpu_alarm_configuration" {
  command = plan

  variables {
    alarm_prefix      = "test"
    sns_topic_name    = "test-alerts"
    email_addresses   = ["test@example.com"]
    ecs_cluster_name  = "test-cluster"
    ecs_service_name  = "test-service"
    create_cpu_alarm  = true
    cpu_threshold     = 80
  }

  # Verify CPU alarm is created with correct threshold
  assert {
    condition     = var.create_cpu_alarm ? aws_cloudwatch_metric_alarm.ecs_cpu[0].threshold == var.cpu_threshold : true
    error_message = "CPU alarm threshold should match the configured value"
  }

  # Verify CPU alarm monitors correct metric
  assert {
    condition     = var.create_cpu_alarm ? aws_cloudwatch_metric_alarm.ecs_cpu[0].metric_name == "CPUUtilization" : true
    error_message = "CPU alarm should monitor CPUUtilization metric"
  }

  # Verify CPU alarm has correct dimensions
  assert {
    condition = var.create_cpu_alarm ? (
      aws_cloudwatch_metric_alarm.ecs_cpu[0].dimensions["ClusterName"] == var.ecs_cluster_name &&
      aws_cloudwatch_metric_alarm.ecs_cpu[0].dimensions["ServiceName"] == var.ecs_service_name
    ) : true
    error_message = "CPU alarm should have correct ECS cluster and service dimensions"
  }
}

run "verify_log_metric_filter" {
  command = plan

  variables {
    alarm_prefix             = "test"
    sns_topic_name           = "test-alerts"
    email_addresses          = ["test@example.com"]
    create_log_metric_filter = true
    log_group_name           = "/ecs/test-cluster/test-service"
    log_filter_pattern       = "ERROR"
    log_threshold            = 10
  }

  # Verify log metric filter is created
  assert {
    condition     = var.create_log_metric_filter ? aws_cloudwatch_log_metric_filter.error_log[0].pattern == var.log_filter_pattern : true
    error_message = "Log metric filter should use the configured pattern"
  }

  # Verify log alarm threshold
  assert {
    condition     = var.create_log_metric_filter ? aws_cloudwatch_metric_alarm.error_log[0].threshold == var.log_threshold : true
    error_message = "Log alarm threshold should match configured value"
  }
}
