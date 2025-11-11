variable "alarm_prefix" {
  description = "Prefix for alarm names"
  type        = string
}

variable "sns_topic_name" {
  description = "Name of the SNS topic"
  type        = string
}

variable "email_addresses" {
  description = "List of email addresses to send notifications to"
  type        = list(string)
}

variable "kms_key_id" {
  description = "KMS key ID for SNS topic encryption"
  type        = string
  default     = null
}

variable "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
  default     = ""
}

variable "ecs_service_name" {
  description = "Name of the ECS service"
  type        = string
  default     = ""
}

variable "create_cpu_alarm" {
  description = "Create CPU utilization alarm"
  type        = bool
  default     = true
}

variable "cpu_threshold" {
  description = "CPU utilization threshold percentage"
  type        = number
  default     = 80
}

variable "cpu_evaluation_periods" {
  description = "Number of periods to evaluate for CPU alarm"
  type        = number
  default     = 2
}

variable "cpu_period" {
  description = "Period in seconds for CPU alarm"
  type        = number
  default     = 300
}

variable "create_memory_alarm" {
  description = "Create memory utilization alarm"
  type        = bool
  default     = true
}

variable "memory_threshold" {
  description = "Memory utilization threshold percentage"
  type        = number
  default     = 80
}

variable "memory_evaluation_periods" {
  description = "Number of periods to evaluate for memory alarm"
  type        = number
  default     = 2
}

variable "memory_period" {
  description = "Period in seconds for memory alarm"
  type        = number
  default     = 300
}

variable "create_log_metric_filter" {
  description = "Create log metric filter and alarm"
  type        = bool
  default     = false
}

variable "log_group_name" {
  description = "CloudWatch log group name"
  type        = string
  default     = ""
}

variable "log_filter_pattern" {
  description = "Log filter pattern (e.g., 'ERROR' or '[ERROR]')"
  type        = string
  default     = "ERROR"
}

variable "log_threshold" {
  description = "Number of log matches to trigger alarm"
  type        = number
  default     = 10
}

variable "log_evaluation_periods" {
  description = "Number of periods to evaluate for log alarm"
  type        = number
  default     = 1
}

variable "log_period" {
  description = "Period in seconds for log alarm"
  type        = number
  default     = 60
}

variable "create_alb_alarm" {
  description = "Create ALB unhealthy targets alarm"
  type        = bool
  default     = false
}

variable "alb_arn_suffix" {
  description = "ARN suffix of the ALB"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
