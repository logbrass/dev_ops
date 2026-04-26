from pydantic import BaseModel
from typing import Optional

class UserSignupRequest(BaseModel):
    username: str
    password: str
    first_name: str

class AuthResponse(BaseModel):
    message: str
    user_id: Optional[int] = None

class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int