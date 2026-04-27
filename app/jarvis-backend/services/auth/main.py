from fastapi import FastAPI
from app.routers import auth
from app.config import settings
from app.models.db import create_tables


app = FastAPI(
    title=settings.app_name,
    debug=settings.debug,
    ignore_trailing_slash=True,
    root_path="/auth",
)

@app.on_event("startup")
def startup_event():
    create_tables()

# Include routers
app.include_router(auth.router)

@app.get("/")
def read_root():
    return {"service": settings.app_name}
