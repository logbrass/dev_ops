from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlalchemy.orm import Session
from typing import List
from ..models.db import get_db
from ..schemas.notes import NoteCreate, NoteUpdate, NoteResponse
from ..services.notes import (
    get_notes_by_user_id,
    get_note_by_id,
    create_note,
    update_note,
    delete_note
)
from shared.auth_client import AuthClient
from shared.schemas.user import UserResponse
from ..config import settings

# Create auth client instance
auth_client = AuthClient(settings.auth_service_url)

async def get_current_user(request: Request) -> UserResponse:
    """Get current user by validating Bearer token with auth service"""
    return await auth_client.get_current_user_from_bearer_token(request)

router = APIRouter(
    prefix="/notes",
    tags=["notes"]
)

@router.get("", response_model=List[NoteResponse])
async def list_notes(
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    notes = get_notes_by_user_id(db, current_user.id)
    return notes

@router.get("/{note_id}", response_model=NoteResponse)
async def get_note(
    note_id: int,
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    note = get_note_by_id(db, note_id, current_user.id)
    if not note:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Note not found"
        )
    return note

@router.post("", response_model=NoteResponse)
async def create_new_note(
    note_data: NoteCreate,
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    new_note = create_note(db, note_data, current_user.id)
    return new_note

@router.put("/{note_id}", response_model=NoteResponse)
async def update_existing_note(
    note_id: int,
    note_data: NoteUpdate,
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    updated_note = update_note(db, note_id, note_data, current_user.id)
    if not updated_note:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Note not found"
        )
    return updated_note

@router.delete("/{note_id}")
async def delete_existing_note(
    note_id: int,
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    success = delete_note(db, note_id, current_user.id)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Note not found"
        )
    return {"message": "Note deleted successfully"}