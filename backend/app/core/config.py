import importlib
import json
from functools import lru_cache
from typing import Any, List
from urllib.parse import quote_plus

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    app_env: str = Field(default="dev", alias="APP_ENV")

    AWS_ACCESS_KEY_ID: str = Field(default="", alias="AWS_ACCESS_KEY_ID")
    AWS_SECRET_ACCESS_KEY: str = Field(default="", alias="AWS_SECRET_ACCESS_KEY")
    
    database_url_override: str = Field(
        default="",
        alias="DATABASE_URL",
    )
    database_name: str = Field(default="pantry_pilot", alias="DATABASE_NAME")
    database_user: str = Field(default="pantry_user", alias="DATABASE_USER")
    database_password: str = Field(default="pantry_pass", alias="DATABASE_PASSWORD")
    database_host: str = Field(default="localhost", alias="DATABASE_HOST")
    database_port: int = Field(default=5432, alias="DATABASE_PORT")
    database_secret_arn: str = Field(default="", alias="DATABASE_SECRET_ARN")
    aws_region: str = Field(default="", alias="AWS_REGION")
    allowed_origins: str = Field(default="*", alias="ALLOWED_ORIGINS")

    # Cognito — left empty by default so local dev can use the X-User-Id fallback.
    cognito_region: str = Field(default="", alias="COGNITO_REGION")
    cognito_user_pool_id: str = Field(default="", alias="COGNITO_USER_POOL_ID")
    cognito_client_id: str = Field(default="", alias="COGNITO_CLIENT_ID")
    cognito_hosted_ui_domain_prefix: str = Field(default="", alias="COGNITO_HOSTED_UI_DOMAIN_PREFIX")
    cognito_hosted_ui_domain: str = Field(default="", alias="COGNITO_HOSTED_UI_DOMAIN")

    # OpenCode AI settings used for AI planning payloads.
    # Uses the openai package to call the OpenAI-compatible endpoint.
    # The base URL should point at the server root (e.g. https://opencode.ai/zen/go/v1);
    # the openai package appends /chat/completions automatically.
    opencode_base_url: str = Field(
        default="https://opencode.ai/zen/go/v1",
        alias="OPENCODE_BASE_URL",
    )
    opencode_model: str = Field(
        default="deepseek-v4-flash",
        alias="OPENCODE_MODEL",
    )
    opencode_api_key: str = Field(
        default="",
        alias="OPENCODE_API_KEY",
    )
    # Optional: sets the model's reasoning effort in the API call.
    # Supported values depend on the model (e.g. "low", "medium", "high").
    # Leave blank to use the model default.
    opencode_reasoning_effort: str = Field(
        default="",
        alias="OPENCODE_REASONING_EFFORT",
    )

    @property
    def allowed_origins_list(self) -> List[str]:
        return [value.strip() for value in self.allowed_origins.split(",") if value.strip()]

    @property
    def database_url(self) -> str:
        """Build SQLAlchemy database URL from env vars and optional secret."""
        if self.database_url_override:
            return self.database_url_override

        encoded_user = quote_plus(self.database_user)
        encoded_password = quote_plus(self._resolved_database_password)
        return (
            f"postgresql+psycopg://{encoded_user}:{encoded_password}"
            f"@{self.database_host}:{self.database_port}/{self.database_name}"
        )

    @property
    def _resolved_database_password(self) -> str:
        if not self.database_secret_arn:
            return self.database_password

        boto3 = importlib.import_module("boto3")
        client = boto3.client(
            "secretsmanager",
            region_name=self.aws_region or None,
        )
        secret_value = client.get_secret_value(SecretId=self.database_secret_arn)
        secret_string = secret_value.get("SecretString")
        if not secret_string:
            raise ValueError("DATABASE_SECRET_ARN did not return SecretString")

        payload = json.loads(secret_string)
        password = payload.get("password")
        if not password:
            raise ValueError("Secrets Manager payload missing 'password'")
        return str(password)

    @property
    def cognito_enabled(self) -> bool:
        """True when both Cognito env vars are set (production / staging)."""
        return bool(self.cognito_region and self.cognito_user_pool_id)

    @property
    def cognito_issuer(self) -> str:
        return f"https://cognito-idp.{self.cognito_region}.amazonaws.com/{self.cognito_user_pool_id}"

    @property
    def cognito_jwks_url(self) -> str:
        return f"{self.cognito_issuer}/.well-known/jwks.json"

    @property
    def cognito_oauth_domain(self) -> str:
        if self.cognito_hosted_ui_domain:
            return self.cognito_hosted_ui_domain.strip().rstrip("/")

        if not self.cognito_hosted_ui_domain_prefix:
            return ""

        prefix = self.cognito_hosted_ui_domain_prefix.strip()
        return f"https://{prefix}.auth.{self.cognito_region}.amazoncognito.com"

    @property
    def cognito_docs_oauth_enabled(self) -> bool:
        """True when Swagger UI can perform Cognito OAuth2 login."""
        return bool(self.cognito_enabled and self.cognito_client_id and self.cognito_oauth_domain)

    @property
    def cognito_oauth_authorize_url(self) -> str:
        return f"{self.cognito_oauth_domain}/oauth2/authorize"

    @property
    def cognito_oauth_token_url(self) -> str:
        return f"{self.cognito_oauth_domain}/oauth2/token"

    @property
    def swagger_ui_init_oauth(self) -> dict[str, Any]:
        if not self.cognito_docs_oauth_enabled:
            return {}

        # Swagger UI requests tokens directly from Cognito using PKCE.
        return {
            "clientId": self.cognito_client_id,
            "appName": "PantryPilot API Docs",
            "usePkceWithAuthorizationCodeGrant": True,
            "scopes": "openid email profile",
        }


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
