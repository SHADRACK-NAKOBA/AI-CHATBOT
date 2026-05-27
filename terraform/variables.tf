variable "environment" {
  description = "Deployment environment: dev, staging, or prod"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod"
  }
}

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project identifier used in resource names and tags"
  type        = string
  default     = "nakoba-chatbot"
}

variable "owner_email" {
  description = "Owner email for billing alerts and alarms"
  type        = string
  default     = "shadrack.n159@gmail.com"
}

variable "anthropic_secret_name" {
  description = "AWS Secrets Manager secret name for the Anthropic API key"
  type        = string
  default     = "nakoba/anthropic-api-key"
}

variable "lambda_memory_mb" {
  description = "Lambda function memory in MB"
  type        = number
  default     = 256
}

variable "lambda_timeout_seconds" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 30
}

variable "rate_limit_per_minute" {
  description = "Max chat requests per minute per IP (DynamoDB-backed)"
  type        = number
  default     = 100
}

variable "waf_rate_limit_per_5min" {
  description = "Max requests per 5 minutes per IP at the WAF level"
  type        = number
  default     = 2000
}

variable "cloudwatch_log_retention_days" {
  description = "CloudWatch log group retention period in days"
  type        = number
  default     = 90
}

variable "monthly_budget_usd" {
  description = "Monthly AWS cost budget in USD — triggers alert at 80% and 100%"
  type        = number
  default     = 50
}

variable "allowed_origin" {
  description = "CORS allowed origin for the Lambda function (set to CloudFront domain after first deploy)"
  type        = string
  default     = "*"
}
