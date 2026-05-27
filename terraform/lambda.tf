#checkov:skip=CKV_AWS_338:Retention period is environment-configurable; set cloudwatch_log_retention_days=365 for compliance environments
#checkov:skip=CKV_AWS_158:KMS encryption for Lambda operational logs not required; no sensitive data in log output
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.name_prefix}"
  retention_in_days = var.cloudwatch_log_retention_days

  tags = { Name = "${local.name_prefix}-logs" }
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.root}/../ai-chatbot/lambda"
  output_path = "${path.root}/lambda.zip"
  excludes    = ["test.js", "*.test.js", "*.zip"]
}

#checkov:skip=CKV_AWS_117:Lambda not in VPC by design — no private data store access; WAF + Secrets Manager endpoints are public
#checkov:skip=CKV_AWS_173:Environment variables contain no secrets; API key retrieved at runtime from Secrets Manager
#checkov:skip=CKV_AWS_272:Code signing not required for this deployment model; integrity ensured via CI/CD pipeline and S3 source hash
resource "aws_lambda_function" "chatbot" {
  function_name                  = local.name_prefix
  role                           = aws_iam_role.lambda.arn
  handler                        = "index.handler"
  runtime                        = "nodejs20.x"
  timeout                        = var.lambda_timeout_seconds
  memory_size                    = var.lambda_memory_mb
  reserved_concurrent_executions = var.lambda_reserved_concurrency

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  environment {
    variables = {
      ENVIRONMENT           = var.environment
      ALLOWED_ORIGIN        = var.allowed_origin
      ANTHROPIC_SECRET_NAME = var.anthropic_secret_name
      RATE_LIMIT_TABLE      = aws_dynamodb_table.rate_limits.name
      RATE_LIMIT_MAX        = tostring(var.rate_limit_per_minute)
      RATE_LIMIT_SALT       = "${var.project_name}-${var.environment}"
    }
  }

  tracing_config {
    mode = "Active"
  }

  depends_on = [
    aws_iam_role_policy.lambda_logs,
    aws_cloudwatch_log_group.lambda,
  ]

  tags = { Name = local.name_prefix }
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.chatbot.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.chatbot.execution_arn}/*/*"
}
