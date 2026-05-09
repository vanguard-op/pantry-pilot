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

output "db_cluster_endpoint" {
  description = "Aurora PostgreSQL cluster endpoint"
  value       = module.rds_aurora.cluster_endpoint
}

output "db_cluster_port" {
  description = "Aurora PostgreSQL cluster port"
  value       = module.rds_aurora.cluster_port
}

output "db_cluster_identifier" {
  description = "Aurora PostgreSQL cluster identifier"
  value       = module.rds_aurora.cluster_id
}

output "db_name" {
  description = "Application database name"
  value       = var.db_name
}

output "db_master_username" {
  description = "Application database username"
  value       = var.db_master_username
  sensitive   = true
}

output "db_master_user_secret_arn" {
  description = "ARN of the master user secret in Secrets Manager"
  value       = module.rds_aurora.cluster_master_user_secret[0].secret_arn
}

output "api_url" {
  description = "Base URL for the Pantry Pilot HTTP API"
  value = try(
    module.api_gateway.api_endpoint,
    module.api_gateway.apigatewayv2_api_api_endpoint,
    module.api_gateway.stage_invoke_url,
  )
}

