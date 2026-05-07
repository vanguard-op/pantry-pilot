from functools import lru_cache
from typing import Any, List

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    app_env: str = Field(default="dev", alias="APP_ENV")
    database_url: str = Field(
        default="postgresql+psycopg://pantry_user:pantry_pass@localhost:5432/pantry_pilot",
        alias="DATABASE_URL",
    )
    allowed_origins: str = Field(default="*", alias="ALLOWED_ORIGINS")

    # Cognito — left empty by default so local dev can use the X-User-Id fallback.
    cognito_region: str = Field(default="", alias="COGNITO_REGION")
    cognito_user_pool_id: str = Field(default="", alias="COGNITO_USER_POOL_ID")
    cognito_client_id: str = Field(default="", alias="COGNITO_CLIENT_ID")
    cognito_hosted_ui_domain_prefix: str = Field(default="", alias="COGNITO_HOSTED_UI_DOMAIN_PREFIX")
    cognito_hosted_ui_domain: str = Field(default="", alias="COGNITO_HOSTED_UI_DOMAIN")

    @property
    def allowed_origins_list(self) -> List[str]:
        return [value.strip() for value in self.allowed_origins.split(",") if value.strip()]

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
