resource "aws_cognito_user_pool" "this" {
  name = "pantry-pilot-user-pool"
  # Authenticate with email and password
  auto_verified_attributes = ["email"]
  username_attributes      = ["email"]

  password_policy {
    minimum_length    = 8
    require_uppercase = true
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
  }


}

resource "aws_cognito_user_pool_client" "this" {
  name                                 = "pantry-pilot-client"
  user_pool_id                         = aws_cognito_user_pool.this.id
  callback_urls                        = ["https://example.com", "http://localhost:8000/docs/oauth2-redirect"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code", "implicit"]
  allowed_oauth_scopes                 = ["email", "openid", "profile"]
  supported_identity_providers         = ["COGNITO"]
}

resource "aws_cognito_user_pool_domain" "this" {
  domain                = "pantry-pilot-auth"
  user_pool_id          = aws_cognito_user_pool.this.id
  managed_login_version = 2
}

resource "aws_cognito_managed_login_branding" "this" {
  client_id    = aws_cognito_user_pool_client.this.id
  user_pool_id = aws_cognito_user_pool.this.id

  use_cognito_provided_values = true
}

resource "aws_cognito_user_group" "this" {
  name         = "superusers"
  user_pool_id = aws_cognito_user_pool.this.id
}
