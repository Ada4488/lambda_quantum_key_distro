output "api_id" {
  description = "The ID of the API Gateway."
  value       = aws_apigatewayv2_api.this.id
}

output "api_endpoint" {
  description = "The endpoint URL for the API Gateway."
  value       = aws_apigatewayv2_api.this.api_endpoint
}

output "stage_name" {
  description = "The name of the API Gateway stage."
  value       = aws_apigatewayv2_stage.this.name
}

output "api_invoke_url" {
  description = "The invoke URL for the API stage."
  value       = "${aws_apigatewayv2_api.this.api_endpoint}/${aws_apigatewayv2_stage.this.name}"
}
