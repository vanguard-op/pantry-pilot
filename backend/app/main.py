import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.exc import SQLAlchemyError

from app.api.routes import (
    feedback,
    health,
    kpi,
    pantry,
    planner,
    recipes,
    recommendations,
    settings,
    shopping,
    substitutions,
)
from app.core.db import engine
from app.core.config import get_settings
from app.core.recipe_seed import seed_recipes_if_empty
from sqlmodel import Session

settings_obj = get_settings()
app = FastAPI(title="PantryPilot API", version="0.1.0")
logger = logging.getLogger(__name__)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings_obj.allowed_origins_list or ["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health.router, prefix="/api/v1")
app.include_router(pantry.router, prefix="/api/v1")
app.include_router(recipes.router, prefix="/api/v1")
app.include_router(planner.router, prefix="/api/v1")
app.include_router(recommendations.router, prefix="/api/v1")
app.include_router(substitutions.router, prefix="/api/v1")
app.include_router(shopping.router, prefix="/api/v1")
app.include_router(settings.router, prefix="/api/v1")
app.include_router(feedback.router, prefix="/api/v1")
app.include_router(kpi.router, prefix="/api/v1")


@app.on_event("startup")
def seed_initial_recipes() -> None:
    try:
        with Session(engine) as session:
            seed_recipes_if_empty(session, seed_user_id=settings_obj.recipe_seed_user_id)
    except SQLAlchemyError:
        logger.exception("Failed to seed starter recipes on startup")
