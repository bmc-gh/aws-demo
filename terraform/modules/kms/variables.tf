variable "key_name" {
  description = "Name of the KMS key"
  type        = string
}

variable "description" {
  description = "Description of the KMS key"
  type        = string
}

variable "deletion_window_in_days" {
  description = "Duration in days after which the key is deleted after destruction"
  type        = number
  default     = 10
}

variable "service_principals" {
  description = "List of AWS service principals that can use the key"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to the KMS key"
  type        = map(string)
  default     = {}
}
