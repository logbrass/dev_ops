from pydantic import Field
from shared.config import BaseServiceSettings


class NotesServiceSettings(BaseServiceSettings):
    """Settings specific to the notes service"""
    # Auth service configuration
    auth_service_url: str = Field(
        description="URL of the auth service"
    )

    app_name: str = Field(
        default="jarvis-notes",
        description="Application name"
    )

settings = NotesServiceSettings()
