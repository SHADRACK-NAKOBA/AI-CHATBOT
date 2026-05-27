environment                   = "prod"
aws_region                    = "us-east-1"
lambda_memory_mb              = 512
lambda_timeout_seconds        = 30
rate_limit_per_minute         = 100
waf_rate_limit_per_5min       = 2000
monthly_budget_usd            = 200
cloudwatch_log_retention_days = 90
# Set allowed_origin to your CloudFront domain after first deploy
# Example: allowed_origin = "https://d1234567890.cloudfront.net"
allowed_origin = "*"
