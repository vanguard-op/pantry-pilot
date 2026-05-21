from typing import Annotated

from fastapi import Depends, Header, HTTPException, Security, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlmodel import Session

from app.core.cognito import verify_cognito_token
from app.core.config import get_settings
from app.core.db import get_session

SessionDep = Annotated[Session, Depends(get_session)]

# HTTPBearer extracts the token from the Authorization header.
# auto_error=False lets us handle the missing-token case ourselves so we
# can provide a clearer error message and support the local-dev fallback.
_bearer = HTTPBearer(auto_error=False)


async def get_current_user_id(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Security(_bearer)] = None,
    x_user_id: Annotated[str | None, Header(alias="X-User-Id")] = None,
) -> str:
    """Resolve the caller's user_id from the request.

    Production / staging (``APP_ENV=staging`` or ``APP_ENV=prod``):
    verifies the Cognito JWT from the ``Authorization: Bearer <token>``
    header and returns the ``sub`` claim.  ``X-User-Id`` is *not* accepted.

    Development (``APP_ENV=dev``, the default):
    prefers the Cognito JWT when present, but falls back to the
    ``X-User-Id`` header when no Bearer token is provided.  This lets
    local tooling, tests, and unauthenticated mobile builds keep working
    without standing up a full Cognito pool on every device.
    """
    settings = get_settings()
    is_dev = settings.app_env.strip().lower() == "dev"

    if settings.cognito_enabled:
        if credentials is not None:
            try:
                return verify_cognito_token(
                    token=credentials.credentials,
                    jwks_url=settings.cognito_jwks_url,
                    issuer=settings.cognito_issuer,
                )
            except ValueError as exc:
                if not is_dev:
                    raise HTTPException(
                        status_code=status.HTTP_401_UNAUTHORIZED,
                        detail=str(exc),
                        headers={"WWW-Authenticate": "Bearer"},
                    ) from exc
                # In dev mode: fall through to X-User-Id instead of
                # failing hard so mobile-dev users see a usable error.

        if not is_dev:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Missing Authorization header",
                headers={"WWW-Authenticate": "Bearer"},
            )
        # Dev-only: fall through to X-User-Id below.

    # Local-dev fallback — X-User-Id header.
    # Reached when Cognito is disabled, or when APP_ENV=dev and no
    # valid Bearer token was provided.
    if not x_user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing X-User-Id header (local dev) or Authorization header",
        )
    return x_user_id


UserIdDep = Annotated[str, Depends(get_current_user_id)]
