from pydantic import BaseModel
from datetime import datetime
from typing import Optional

class NoteCreate(BaseModel):
    title: str
    content: str

class NoteUpdate(BaseModel):
    id: int
    title: Optional[str] = None
    content: Optional[str] = None

class NoteResponse(BaseModel):
    id: int
    user_id: int
    title: str
    content: str
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True