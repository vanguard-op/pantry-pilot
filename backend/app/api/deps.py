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

    Production / staging: verifies the Cognito JWT from the
    ``Authorization: Bearer <token>`` header and returns the ``sub`` claim.

    Local development (COGNITO_USER_POOL_ID not set): falls back to the
    ``X-User-Id`` header so existing tooling and tests keep working.
    """
    settings = get_settings()

    if settings.cognito_enabled:
        if credentials is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Missing Authorization header",
                headers={"WWW-Authenticate": "Bearer"},
            )
        try:
            return verify_cognito_token(
                token=credentials.credentials,
                jwks_url=settings.cognito_jwks_url,
                issuer=settings.cognito_issuer,
            )
        except ValueError as exc:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=str(exc),
                headers={"WWW-Authenticate": "Bearer"},
            ) from exc

    # Local-dev fallback — X-User-Id header.
    if not x_user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing X-User-Id header (local dev) or Authorization header",
        )
    return x_user_id


UserIdDep = Annotated[str, Depends(get_current_user_id)]
