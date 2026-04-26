from pydantic import Field
from shared.config import BaseServiceSettings


class AuthServiceSettings(BaseServiceSettings):
    """Settings specific to the auth service"""
    # JWT settings
    jwt_secret_key: str = Field(
        description="Secret key for JWT token signing"
    )
    jwt_algorithm: str = Field(
        default="HS256",
        description="Algorithm for JWT token signing"
    )
    access_token_expire_minutes: int = Field(
        default=30,
        description="JWT token expiration time in minutes"
    )
    refresh_token_expire_days: int = Field(
        default=30,
        description="Refresh token expiration time in days"
    )

    # Cookie security settings
    cookie_secure: bool = Field(
        default=True,
        description="Use secure cookies (HTTPS only)"
    )
    cookie_samesite: str = Field(
        default="strict",
        description="SameSite cookie attribute"
    )

    app_name: str = Field(
        default="jarvis-auth",
        description="Application name"
    )

settings = AuthServiceSettings()
