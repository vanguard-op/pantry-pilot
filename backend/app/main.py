from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes import feedback, health, kpi, pantry, planner, recipes, settings, shopping
from app.core.config import get_settings

settings_obj = get_settings()
app = FastAPI(title="PantryPilot API", version="0.1.0")

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
app.include_router(shopping.router, prefix="/api/v1")
app.include_router(settings.router, prefix="/api/v1")
app.include_router(feedback.router, prefix="/api/v1")
app.include_router(kpi.router, prefix="/api/v1")
