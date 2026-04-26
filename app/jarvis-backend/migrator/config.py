from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class MigratorSettings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env.local",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore"
    )

    # Database settings
    database_url: str = Field(
        description="Database URL for SQLAlchemy"
    )

settings = MigratorSettings()
