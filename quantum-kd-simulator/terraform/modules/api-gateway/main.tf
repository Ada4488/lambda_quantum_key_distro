resource "aws_apigatewayv2_api" "this" {
  name          = var.api_name
  protocol_type = "HTTP"
  description   = "API Gateway for QKD Simulator"
  tags          = var.common_tags

  cors_configuration {
    allow_credentials = false
    allow_headers     = ["content-type", "x-amz-date", "authorization", "x-api-key", "x-amz-security-token", "x-amz-user-agent"]
    allow_methods     = ["*"]
    allow_origins     = ["*"]
    expose_headers    = ["date", "keep-alive"]
    max_age          = 86400
  }
}

resource "aws_apigatewayv2_stage" "this" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = var.stage_name
  auto_deploy = true
  tags        = var.common_tags

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw_logs.arn
    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
      }
    )
  }
}

resource "aws_apigatewayv2_integration" "lambda_qkd_simulator" {
  api_id           = aws_apigatewayv2_api.this.id
  integration_type = "AWS_PROXY"
  # integration_uri  = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${var.lambda_invoke_arn}/invocations" # Incorrect for HTTP API direct lambda integration
  integration_uri = var.lambda_invoke_arn # For HTTP APIs, this is the Lambda function ARN or alias ARN
  payload_format_version = "2.0" # For Lambda proxy integration with Python
  # connection_type = "INTERNET" # Default, not needed for Lambda
  # integration_method = "POST" # Not needed for AWS_PROXY with $default route
}

resource "aws_apigatewayv2_route" "qkd_simulator_post" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "POST /api/v1/qkd/generate"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_qkd_simulator.id}"
}

# Health check endpoint
resource "aws_apigatewayv2_route" "health_check" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "GET /api/v1/health"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_qkd_simulator.id}"
}

# Session details endpoint
resource "aws_apigatewayv2_route" "session_details" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "GET /api/v1/qkd/session/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_qkd_simulator.id}"
}

resource "aws_lambda_permission" "api_gw_invoke_lambda" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"

  # Allow access from any method on any resource within the API Gateway
  source_arn = "arn:aws:execute-api:${var.aws_region}:${var.aws_account_id}:${aws_apigatewayv2_api.this.id}/*/*"
}

resource "aws_cloudwatch_log_group" "api_gw_logs" {
  name              = "/aws/api_gw/${var.api_name}-${var.stage_name}"
  retention_in_days = 30
  tags              = var.common_tags
}
