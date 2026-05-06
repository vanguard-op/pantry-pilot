output "cognito_user_pool_id" {
  description = "The ID of the Cognito User Pool"
  value       = aws_cognito_user_pool.this.id
}

output "cognito_user_pool_arn" {
  description = "The ARN of the Cognito User Pool"
  value       = aws_cognito_user_pool.this.arn
}

output "cognito_user_pool_endpoint" {
  description = "The endpoint of the Cognito User Pool (issuer URL)"
  value       = "https://${aws_cognito_user_pool.this.endpoint}"
}

output "cognito_client_id" {
  description = "The ID of the Cognito User Pool Client"
  value       = aws_cognito_user_pool_client.this.id
}

output "cognito_hosted_ui_url" {
  description = "The base URL for the Cognito hosted UI"
  value       = "https://${aws_cognito_user_pool_domain.this.domain}.auth.${data.aws_region.current.region}.amazoncognito.com"
}

output "media_bucket_name" {
  description = "The name of the S3 media bucket"
  value       = module.media_bucket.s3_bucket_id
}

output "media_bucket_arn" {
  description = "The ARN of the S3 media bucket"
  value       = module.media_bucket.s3_bucket_arn
}

output "media_bucket_domain_name" {
  description = "The regional domain name of the S3 media bucket"
  value       = module.media_bucket.s3_bucket_bucket_regional_domain_name
}

