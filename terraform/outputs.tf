output "cloudfront_domain" {
  description = "CloudFront distribution domain — set this as ALLOWED_ORIGIN and use as the app URL"
  value       = "https://${aws_cloudfront_distribution.frontend.domain_name}"
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID (needed for cache invalidation)"
  value       = aws_cloudfront_distribution.frontend.id
}

output "api_gateway_url" {
  description = "Direct API Gateway URL (used internally by CloudFront; prefer cloudfront_domain)"
  value       = aws_apigatewayv2_api.chatbot.api_endpoint
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.chatbot.function_name
}

output "lambda_function_arn" {
  description = "Lambda function ARN"
  value       = aws_lambda_function.chatbot.arn
}

output "frontend_bucket_name" {
  description = "S3 bucket name for the frontend"
  value       = aws_s3_bucket.frontend.bucket
}

output "rate_limit_table_name" {
  description = "DynamoDB table name for rate limiting"
  value       = aws_dynamodb_table.rate_limits.name
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group for Lambda"
  value       = aws_cloudwatch_log_group.lambda.name
}

output "sns_alerts_arn" {
  description = "SNS topic ARN for alerts"
  value       = aws_sns_topic.alerts.arn
}
