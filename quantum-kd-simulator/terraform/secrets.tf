resource "aws_secretsmanager_secret" "qkd_app_secrets" {
  name        = "${var.environment}-qkd-app-secrets"
  description = "Application secrets for the QKD Simulator in ${var.environment} environment."

  tags = {
    Environment = var.environment
    Project     = "quantum-kd-simulator"
    ManagedBy   = "terraform"
  }

  lifecycle {
    ignore_changes = [
      # Ignore changes to secret_string if managed externally after initial set up
      # aws_secretsmanager_secret_version.initial_app_secrets.secret_string 
    ]
  }
}

# This resource defines an initial version of the secret.
# WARNING: Do not commit actual secret values here in a production environment.
# Populate actual secrets securely (e.g., via AWS Console, CLI, or a secure pipeline).
resource "aws_secretsmanager_secret_version" "initial_app_secrets" {
  secret_id     = aws_secretsmanager_secret.qkd_app_secrets.id
  secret_string = jsonencode({
    EXAMPLE_API_KEY   = "PLACEHOLDER_API_KEY"
    ANOTHER_SECRET_PARAM = "PLACEHOLDER_VALUE"
  })

  # Ensure this version is created only once by Terraform, if desired.
  # Or, allow updates if Terraform is the source of truth for these placeholders.
  # lifecycle {
  #   prevent_destroy = true # Optional: protect this version from accidental deletion
  # }
}

data "aws_secretsmanager_secret_version" "current_app_secrets" {
  secret_id = aws_secretsmanager_secret.qkd_app_secrets.id
  # Ensure this data source depends on the initial version being set if you need to read it immediately
  depends_on = [aws_secretsmanager_secret_version.initial_app_secrets]
}

output "qkd_app_secrets_arn" {
  description = "ARN of the QKD application secrets"
  value       = aws_secretsmanager_secret.qkd_app_secrets.arn
  sensitive   = true
}
