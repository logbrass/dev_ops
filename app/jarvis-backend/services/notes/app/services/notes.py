from typing import List, Optional
from sqlalchemy.orm import Session
from ..models.notes import Note
from ..schemas.notes import NoteCreate, NoteUpdate


def get_notes_by_user_id(db: Session, user_id: int) -> List[Note]:
    """Get all notes for a specific user"""
    return db.query(Note).filter(Note.user_id == user_id).all()


def get_note_by_id(db: Session, note_id: int, user_id: int) -> Optional[Note]:
    """Get a specific note by ID for a user"""
    return db.query(Note).filter(Note.id == note_id, Note.user_id == user_id).first()


def create_note(db: Session, note_data: NoteCreate, user_id: int) -> Note:
    """Create a new note for a user"""
    new_note = Note(
        user_id=user_id,
        title=note_data.title,
        content=note_data.content
    )
    db.add(new_note)
    db.commit()
    db.refresh(new_note)
    return new_note


def update_note(db: Session, note_id: int, note_data: NoteUpdate, user_id: int) -> Optional[Note]:
    """Update an existing note for a user"""
    note = db.query(Note).filter(Note.id == note_id, Note.user_id == user_id).first()
    if not note:
        return None
    
    if note_data.title is not None:
        note.title = note_data.title
    if note_data.content is not None:
        note.content = note_data.content
    
    db.commit()
    db.refresh(note)
    return note


def delete_note(db: Session, note_id: int, user_id: int) -> bool:
    """Delete a note for a user"""
    note = db.query(Note).filter(Note.id == note_id, Note.user_id == user_id).first()
    if not note:
        return False
    
    db.delete(note)
    db.commit()
    return True