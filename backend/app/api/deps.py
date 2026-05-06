from typing import Annotated

from fastapi import Depends, Header, HTTPException, status
from sqlmodel import Session

from app.core.db import get_session

SessionDep = Annotated[Session, Depends(get_session)]


async def get_current_user_id(
    x_user_id: Annotated[str | None, Header(alias="X-User-Id")] = None,
) -> str:
    # Temporary auth bridge before Cognito integration.
    if not x_user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing X-User-Id header",
        )
    return x_user_id


UserIdDep = Annotated[str, Depends(get_current_user_id)]
