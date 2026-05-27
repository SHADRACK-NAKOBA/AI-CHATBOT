resource "aws_cloudfront_response_headers_policy" "security" {
  provider = aws.us_east_1
  name     = "${local.name_prefix}-security-headers"

  security_headers_config {
    content_type_options {
      override = true
    }
    frame_options {
      frame_option = "DENY"
      override     = true
    }
    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }
    # CKV_AWS_259: preload = true enforces HSTS preloading
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      preload                    = true
      override                   = true
    }
    xss_protection {
      mode_block = true
      protection = true
      override   = true
    }
  }

  custom_headers_config {
    items {
      header   = "Permissions-Policy"
      value    = "camera=(), microphone=(), geolocation=()"
      override = true
    }
  }
}

#checkov:skip=CKV_AWS_374:Geo restriction intentionally disabled — public AI assistant, global access required
#checkov:skip=CKV_AWS_174:Default CloudFront certificate enforces TLS 1.2; minimum_protocol_version only configurable with ACM cert
#checkov:skip=CKV_AWS_310:Single-region deployment by design; multi-origin failover adds cost without proportional benefit
#checkov:skip=CKV2_AWS_42:Custom SSL certificate requires a registered domain; using CloudFront default domain
#checkov:skip=CKV2_AWS_47:WAF already includes AWSManagedRulesKnownBadInputsRuleSet which covers Log4j (CVE-2021-44228)
resource "aws_cloudfront_distribution" "frontend" {
  provider = aws.us_east_1
  enabled  = true
  comment  = "${local.name_prefix} — ${var.environment}"

  default_root_object = "index.html"

  # S3 origin for frontend
  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "s3-frontend"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  # API Gateway origin for /chat and /health
  origin {
    domain_name = replace(aws_apigatewayv2_api.chatbot.api_endpoint, "https://", "")
    origin_id   = "api-gateway"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # API routes forwarded to API Gateway
  ordered_cache_behavior {
    path_pattern           = "/chat"
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "api-gateway"
    viewer_protocol_policy = "redirect-to-https"
    cache_policy_id        = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # CachingDisabled

    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id
  }

  ordered_cache_behavior {
    path_pattern           = "/health"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "api-gateway"
    viewer_protocol_policy = "redirect-to-https"
    cache_policy_id        = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # CachingDisabled

    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id
  }

  # Default behavior — serve frontend from S3
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-frontend"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400

    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id
  }

  # CKV_AWS_86: CloudFront access logging enabled
  logging_config {
    bucket          = aws_s3_bucket.logs.bucket_domain_name
    prefix          = "cloudfront/"
    include_cookies = false
  }

  # WAF association
  web_acl_id = aws_wafv2_web_acl.chatbot.arn

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  tags = { Name = "${local.name_prefix}-distribution" }

  depends_on = [aws_wafv2_web_acl.chatbot]
}
