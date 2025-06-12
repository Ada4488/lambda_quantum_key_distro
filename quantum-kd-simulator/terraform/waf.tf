# AWS WAFv2 Web ACL and Rules will be defined here

resource "aws_wafv2_web_acl" "api_gateway_acl" {
  name        = "${var.environment}-qkd-api-acl"
  description = "WAF ACL for QKD Simulator API Gateway in ${var.environment}"
  scope       = "REGIONAL" # For API Gateway, ALB, AppSync

  default_action {
    allow {}
  }

  # Rule for AWS Managed Core Rule Set
  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesCommonRuleSet"
        # You can exclude specific rules if needed, for example:
        # excluded_rule {
        #   name = "SizeRestrictions_BODY"
        # }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.environment}WAFCommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # Rule for SQL Injection Protection
  rule {
    name     = "AWS-AWSManagedRulesSQLiRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesSQLiRuleSet"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.environment}WAFSQLiRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # Example: Rate-based rule (e.g., limit requests per IP)
  # This is a basic example; adjust thresholds and criteria as needed.
  rule {
    name     = "RateLimitRule"
    priority = 3

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000 # Requests per 5-minute period per IP
        aggregate_key_type = "IP"
        # You can scope this down to specific URIs if needed
        # scope_down_statement {
        #   text_transformation_statement {
        #     priority = 0
        #     statement {
        #       uri_path_statement {
        #         strings = ["/api/v1/qkd/generate"]
        #       }
        #     }
        #     text_transformation {
        #       priority = 0
        #       type     = "NONE"
        #     }
        #   }
        # }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.environment}WAFRateLimit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.environment}WAFDefaultAction"
    sampled_requests_enabled   = true
  }

  tags = {
    Name        = "${var.environment}-qkd-api-acl"
    Environment = var.environment
    Project     = "quantum-kd-simulator"
    ManagedBy   = "terraform"
  }
}

output "waf_acl_arn" {
  description = "ARN of the WAFv2 Web ACL for API Gateway"
  value       = aws_wafv2_web_acl.api_gateway_acl.arn
  sensitive   = true
}
