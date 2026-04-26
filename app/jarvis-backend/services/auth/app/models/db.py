from shared.database import create_database_engine, create_session_local, get_database_dependency, Base
from ..config import settings

# Create engine and session
engine = create_database_engine(settings.database_url)
SessionLocal = create_session_local(engine)

# Create database dependency
get_db = get_database_dependency(SessionLocal)

def create_tables():
    """Create all tables for the notes service"""
    Base.metadata.create_all(bind=engine)