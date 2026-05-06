from functools import lru_cache
from typing import List

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
    recipe_seed_user_id: str = Field(default="mobile-user-1", alias="RECIPE_SEED_USER_ID")

    # Cognito — left empty by default so local dev can use the X-User-Id fallback.
    cognito_region: str = Field(default="", alias="COGNITO_REGION")
    cognito_user_pool_id: str = Field(default="", alias="COGNITO_USER_POOL_ID")

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


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
