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

    @property
    def allowed_origins_list(self) -> List[str]:
        return [value.strip() for value in self.allowed_origins.split(",") if value.strip()]


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
