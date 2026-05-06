"""Cognito JWT verification utilities.

Fetches the JWKS from Cognito once (cached in-process) and verifies
incoming Bearer tokens.  The user's Cognito ``sub`` claim becomes the
canonical user_id used throughout the app.
"""

from functools import lru_cache

import httpx
from jose import JWTError, jwk, jwt
from jose.utils import base64url_decode


@lru_cache(maxsize=1)
def _get_jwks(jwks_url: str) -> dict:
    """Download and cache the JWKS from Cognito.

    Uses an in-process LRU cache so the network call is made once per
    interpreter lifetime.  Restart the container to force a refresh.
    """
    response = httpx.get(jwks_url, timeout=5)
    response.raise_for_status()
    return response.json()


def verify_cognito_token(token: str, jwks_url: str, issuer: str) -> str:
    """Verify a Cognito JWT and return the ``sub`` claim (user_id).

    Args:
        token:     Raw JWT string (without the ``Bearer `` prefix).
        jwks_url:  The JWKS endpoint for the Cognito User Pool.
        issuer:    The expected ``iss`` claim value.

    Returns:
        The ``sub`` claim (stable Cognito user UUID).

    Raises:
        ValueError: If the token is invalid, expired, or unverifiable.
    """
    jwks = _get_jwks(jwks_url)

    try:
        # Decode header without verification to find the matching key.
        unverified_header = jwt.get_unverified_header(token)
    except JWTError as exc:
        raise ValueError("Invalid token header") from exc

    kid = unverified_header.get("kid")
    matching_key = next(
        (k for k in jwks.get("keys", []) if k.get("kid") == kid),
        None,
    )
    if matching_key is None:
        raise ValueError("Public key not found for token kid")

    try:
        public_key = jwk.construct(matching_key)
        claims = jwt.decode(
            token,
            public_key,
            algorithms=["RS256"],
            issuer=issuer,
            options={"verify_at_hash": False},
        )
    except JWTError as exc:
        raise ValueError(f"Token verification failed: {exc}") from exc

    sub: str | None = claims.get("sub")
    if not sub:
        raise ValueError("Token missing 'sub' claim")

    return sub
