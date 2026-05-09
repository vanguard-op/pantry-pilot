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
  callback_urls                        = ["pantrypilot://auth", "http://localhost:8000/docs/oauth2-redirect", "https://hcpmu33z78.execute-api.us-east-1.amazonaws.com/docs/oauth2-redirect"]
  logout_urls                          = ["pantrypilot://auth/logout"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["email", "openid", "profile", "aws.cognito.signin.user.admin"]
  supported_identity_providers         = ["COGNITO"]
  read_attributes                      = ["email", "email_verified", "family_name", "given_name", "sub"]
  write_attributes                     = ["family_name", "given_name"]

  # Required for PKCE (mobile OAuth2 code flow)
  prevent_user_existence_errors = "ENABLED"
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
