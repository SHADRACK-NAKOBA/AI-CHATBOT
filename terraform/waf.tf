# WAF must be in us-east-1 for CloudFront
resource "aws_wafv2_web_acl" "chatbot" {
  provider    = aws.us_east_1
  name        = local.name_prefix
  scope       = "CLOUDFRONT"
  description = "WAF for ${local.name_prefix}"

  default_action {
    allow {}
  }

  # Priority 10: AWS Managed Common Rule Set (OWASP Top 10)
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 10

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-common-rules"
      sampled_requests_enabled   = true
    }
  }

  # Priority 20: Known Bad Inputs (Log4Shell, Spring4Shell, SSRF)
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 20

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  # Priority 30: SQL Injection
  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 30

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-sqli"
      sampled_requests_enabled   = true
    }
  }

  # Priority 40: IP Reputation (known bad IPs, botnets)
  rule {
    name     = "AWSManagedRulesAmazonIpReputationList"
    priority = 40

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-ip-reputation"
      sampled_requests_enabled   = true
    }
  }

  # Priority 50: Rate limit — 2000 requests per 5 minutes per IP
  rule {
    name     = "RateLimitRule"
    priority = 50

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit_per_5min
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.name_prefix}-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = local.name_prefix
    sampled_requests_enabled   = true
  }

  tags = { Name = "${local.name_prefix}-waf" }
}

# WAF log group — name MUST start with "aws-waf-logs-" per AWS requirement
#checkov:skip=CKV_AWS_338:Retention period is environment-configurable; set cloudwatch_log_retention_days=365 for compliance
#checkov:skip=CKV_AWS_158:KMS encryption for WAF operational logs not required; no sensitive data in WAF access logs
resource "aws_cloudwatch_log_group" "waf" {
  provider          = aws.us_east_1
  name              = "aws-waf-logs-${local.name_prefix}"
  retention_in_days = var.cloudwatch_log_retention_days

  tags = { Name = "aws-waf-logs-${local.name_prefix}" }
}

# CKV_AWS_176: WAF logging enabled
resource "aws_wafv2_web_acl_logging_configuration" "chatbot" {
  provider                = aws.us_east_1
  resource_arn            = aws_wafv2_web_acl.chatbot.arn
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]
}
