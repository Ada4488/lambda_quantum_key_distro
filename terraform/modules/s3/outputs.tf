output "primary_bucket_id" {
  description = "The name of the primary S3 bucket."
  value       = aws_s3_bucket.primary_bucket.id
}

output "primary_bucket_arn" {
  description = "The ARN of the primary S3 bucket."
  value       = aws_s3_bucket.primary_bucket.arn
}

output "primary_bucket_domain_name" {
  description = "The domain name of the primary S3 bucket."
  value       = aws_s3_bucket.primary_bucket.bucket_regional_domain_name
}
