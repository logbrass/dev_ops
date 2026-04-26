from datetime import timedelta
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session

from shared.schemas.user import UserResponse

from ..models.db import get_db
from ..models.user import User
from ..services.auth import (
    authenticate_user,
    create_access_token,
    create_refresh_token,
    get_current_user_from_token,
    get_password_hash,
    verify_token,
    get_user_by_username
)
from ..config import settings
from ..schemas.user import AuthResponse, UserSignupRequest, TokenResponse

router = APIRouter(
    tags=["authentication"]
)

@router.post("/signup", response_model=AuthResponse)
def signup(
    user_data: UserSignupRequest,
    db: Session = Depends(get_db)
):
    # Check if user already exists
    existing_user = db.query(User).filter(User.username == user_data.username).first()
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Username already registered"
        )

    # Create new user
    hashed_password = get_password_hash(user_data.password)
    new_user = User(
        username=user_data.username,
        hashed_password=hashed_password,
        first_name=user_data.first_name,
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    return AuthResponse(message="User created successfully", user_id=new_user.id)

@router.post("/token", response_model=TokenResponse)
def login_for_access_token(
    form_data: Annotated[OAuth2PasswordRequestForm, Depends()],
    db: Session = Depends(get_db)
):
    print("login req")
    print(form_data)
    user = authenticate_user(db, form_data.username, form_data.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    access_token_expires = timedelta(minutes=settings.access_token_expire_minutes)
    refresh_token_expires = timedelta(days=settings.refresh_token_expire_days)

    access_token = create_access_token(
        data={"sub": user.username}, expires_delta=access_token_expires
    )
    refresh_token = create_refresh_token(
        data={"sub": user.username}, expires_delta=refresh_token_expires
    )

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        token_type="bearer",
        expires_in=settings.access_token_expire_minutes * 60
    )

@router.post("/refresh", response_model=TokenResponse)
def refresh_access_token(
    refresh_token: str,
    db: Session = Depends(get_db)
):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )

    username = verify_token(refresh_token, "refresh")
    if username is None:
        raise credentials_exception

    user = get_user_by_username(db, username)
    if user is None:
        raise credentials_exception

    # Generate new tokens
    access_token_expires = timedelta(minutes=settings.access_token_expire_minutes)
    refresh_token_expires = timedelta(days=settings.refresh_token_expire_days)

    new_access_token = create_access_token(
        data={"sub": user.username}, expires_delta=access_token_expires
    )
    new_refresh_token = create_refresh_token(
        data={"sub": user.username}, expires_delta=refresh_token_expires
    )

    return TokenResponse(
        access_token=new_access_token,
        refresh_token=new_refresh_token,
        token_type="bearer",
        expires_in=settings.access_token_expire_minutes * 60
    )

@router.get("/profile", response_model=UserResponse)
def get_profile(current_user: User = Depends(get_current_user_from_token)):
    return UserResponse(
        id=current_user.id,
        username=current_user.username,
        first_name=current_user.first_name,
        created_at=current_user.created_at
    )

@router.get("/validate", response_model=UserResponse)
def validate_token(token: str, db: Session = Depends(get_db)):
    """Internal endpoint for other services to validate tokens"""
    username = verify_token(token)
    if username is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token"
        )

    user = get_user_by_username(db, username)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found"
        )

    return UserResponse(
        id=user.id,
        username=user.username,
        first_name=user.first_name,
        created_at=user.created_at
    )