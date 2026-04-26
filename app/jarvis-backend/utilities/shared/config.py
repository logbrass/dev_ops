from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class BaseServiceSettings(BaseSettings):
    """Base settings class for all microservices"""
    model_config = SettingsConfigDict(
        env_file=".env.local",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore"
    )

    frontend_url: str = Field(
        description="Frontend URL"
    )

    # Database settings
    database_url: str = Field(
        description="Database URL for SQLAlchemy"
    )

    # App settings
    debug: bool = Field(
        default=False,
        description="Debug mode"
    )
