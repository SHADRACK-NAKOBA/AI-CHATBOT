resource "aws_sns_topic" "alerts" {
  name = "${local.name_prefix}-alerts"
  tags = { Name = "${local.name_prefix}-alerts" }
}

resource "aws_sns_topic_subscription" "email_alerts" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.owner_email
}

# Alarm: Lambda error rate > 5%
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${local.name_prefix}-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = 5
  alarm_description   = "Lambda error rate exceeded 5% over 5 minutes"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "error_rate"
    expression  = "errors/invocations*100"
    label       = "Error Rate %"
    return_data = true
  }

  metric_query {
    id = "errors"
    metric {
      metric_name = "Errors"
      namespace   = "AWS/Lambda"
      period      = 300
      stat        = "Sum"
      dimensions  = { FunctionName = aws_lambda_function.chatbot.function_name }
    }
  }

  metric_query {
    id = "invocations"
    metric {
      metric_name = "Invocations"
      namespace   = "AWS/Lambda"
      period      = 300
      stat        = "Sum"
      dimensions  = { FunctionName = aws_lambda_function.chatbot.function_name }
    }
  }
}

# Alarm: Lambda P99 latency > 5 seconds
resource "aws_cloudwatch_metric_alarm" "lambda_latency" {
  alarm_name          = "${local.name_prefix}-p99-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  extended_statistic  = "p99"
  threshold           = 5000
  alarm_description   = "Lambda P99 duration exceeded 5 seconds"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"
  dimensions          = { FunctionName = aws_lambda_function.chatbot.function_name }
}

# Alarm: Lambda throttles
resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  alarm_name          = "${local.name_prefix}-lambda-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "Lambda throttling detected"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"
  dimensions          = { FunctionName = aws_lambda_function.chatbot.function_name }
}

# Log metric filter: harmful content blocked
resource "aws_cloudwatch_log_metric_filter" "harmful_content" {
  name           = "${local.name_prefix}-harmful-content"
  log_group_name = aws_cloudwatch_log_group.lambda.name
  pattern        = "{ $.responsibleAI.harmfulContentBlocked = true }"

  metric_transformation {
    name      = "HarmfulContentBlocked"
    namespace = "NakobaAI/Security"
    value     = "1"
  }
}

# Alarm: Spike in harmful content blocks (>50 in 1 hour)
resource "aws_cloudwatch_metric_alarm" "harmful_content_spike" {
  alarm_name          = "${local.name_prefix}-responsible-ai-block"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HarmfulContentBlocked"
  namespace           = "NakobaAI/Security"
  period              = 3600
  statistic           = "Sum"
  threshold           = 50
  alarm_description   = "Spike in harmful content blocks — possible abuse attempt"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"
}

# Log metric filter: PII detected
resource "aws_cloudwatch_log_metric_filter" "pii_detected" {
  name           = "${local.name_prefix}-pii-detected"
  log_group_name = aws_cloudwatch_log_group.lambda.name
  pattern        = "{ $.responsibleAI.piiDetected = true }"

  metric_transformation {
    name      = "PIIDetected"
    namespace = "NakobaAI/Security"
    value     = "1"
  }
}

# AWS Budget
resource "aws_budgets_budget" "monthly" {
  name         = "${local.name_prefix}-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.owner_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.owner_email]
  }
}
