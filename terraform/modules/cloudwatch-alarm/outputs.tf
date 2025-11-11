output "sns_topic_arn" {
  description = "ARN of the SNS topic"
  value       = aws_sns_topic.alarm.arn
}

output "sns_topic_name" {
  description = "Name of the SNS topic"
  value       = aws_sns_topic.alarm.name
}

output "cpu_alarm_arn" {
  description = "ARN of the CPU alarm"
  value       = var.create_cpu_alarm ? aws_cloudwatch_metric_alarm.ecs_cpu[0].arn : null
}

output "memory_alarm_arn" {
  description = "ARN of the memory alarm"
  value       = var.create_memory_alarm ? aws_cloudwatch_metric_alarm.ecs_memory[0].arn : null
}

output "log_alarm_arn" {
  description = "ARN of the log alarm"
  value       = var.create_log_metric_filter ? aws_cloudwatch_metric_alarm.error_log[0].arn : null
}
