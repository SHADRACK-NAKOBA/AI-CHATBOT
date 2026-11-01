environment                   = "dev"
owner_email                   = "CHANGE_ME@example.com" # <-- REQUIRED: put YOUR email here (alarms + budget alerts)
aws_region                    = "us-east-1"
lambda_memory_mb              = 256
lambda_timeout_seconds        = 30
lambda_reserved_concurrency   = -1 # -1 = unreserved. Raise (e.g. 50) only after checking Service Quotas > Lambda > Concurrent executions
rate_limit_per_minute         = 200
waf_rate_limit_per_5min       = 5000
monthly_budget_usd            = 50
cloudwatch_log_retention_days = 30
allowed_origin                = "*"
