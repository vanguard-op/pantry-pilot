import logging
from typing import Any
from fastapi import FastAPI
from fastapi.openapi.utils import get_openapi
from fastapi.middleware.cors import CORSMiddleware

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
from app.core.config import get_settings

settings_obj = get_settings()
app = FastAPI(
    title="PantryPilot API",
    version="0.1.0",
    swagger_ui_init_oauth=settings_obj.swagger_ui_init_oauth,
)
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


def custom_openapi() -> dict[str, Any]:
    if app.openapi_schema:
        return app.openapi_schema

    openapi_schema = get_openapi(
        title=app.title,
        version=app.version,
        routes=app.routes,
    )

    if settings_obj.cognito_docs_oauth_enabled:
        components = openapi_schema.setdefault("components", {})
        security_schemes = components.setdefault("securitySchemes", {})

        # Keep the existing scheme key so generated operation security references
        # continue to work without rewriting every path item.
        security_schemes["HTTPBearer"] = {
            "type": "oauth2",
            "flows": {
                "authorizationCode": {
                    "authorizationUrl": settings_obj.cognito_oauth_authorize_url,
                    "tokenUrl": settings_obj.cognito_oauth_token_url,
                    "scopes": {
                        "openid": "OpenID Connect scope",
                        "email": "User email scope",
                        "profile": "User profile scope",
                        "aws.cognito.signin.user.admin": "Cognito user admin scope",
                    },
                }
            },
        }

    app.openapi_schema = openapi_schema
    return app.openapi_schema


app.openapi = custom_openapi
