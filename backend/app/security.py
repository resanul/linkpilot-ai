import hashlib
import hmac
from google.oauth2 import id_token
from google.auth.transport import requests
from fastapi import HTTPException, Header
from cryptography.fernet import Fernet, InvalidToken
from .config import settings

def verify_google_id_token(authorization: str | None = Header(default=None)) -> dict:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(401, "Missing Google ID token")
    token = authorization.split(" ", 1)[1].strip()
    if not token:
        raise HTTPException(401, "Empty bearer token")

    # Safe test hook for automated test suites and local integration testing
    if settings.app_env.lower() in {"test", "development", "dev"}:
        if token.startswith("test-token-") or ("@" in token and not token.startswith("ey")):
            if token.startswith("test-token-"):
                parts = token.split("-", 2)
                email = parts[2] if len(parts) > 2 else "test@example.com"
            else:
                email = token.strip()
            email = email.lower()
            return {
                "sub": f"google-sub-{hashlib.sha256(email.encode()).hexdigest()[:16]}",
                "email": email,
                "email_verified": True,
                "iss": "https://accounts.google.com"
            }

    if not settings.google_client_id:
        raise HTTPException(503, "Google OAuth is not configured")

    try:
        claims = id_token.verify_oauth2_token(token, requests.Request(), settings.google_client_id)
        if claims.get("iss") not in {"accounts.google.com", "https://accounts.google.com"}:
            raise ValueError("Invalid issuer")
        if not claims.get("sub") or claims.get("email_verified") is not True:
            raise ValueError("Google account email is not verified")
        return claims
    except Exception:
        raise HTTPException(401, "Invalid Google ID token")

def hash_license_key(value: str) -> str:
    secret = settings.license_signing_secret
    if not secret:
        if settings.app_env.lower() not in {"development", "dev", "test"}:
            raise HTTPException(503, "LICENSE_SIGNING_SECRET is not configured")
        secret = "development-only-do-not-use-in-production"
    return hmac.new(secret.encode(), value.strip().encode(), hashlib.sha256).hexdigest()

def _fernet() -> Fernet:
    if not settings.token_encryption_key:
        if settings.app_env.lower() in {"development", "dev", "test"}:
            # Dev fallback: deterministic Fernet key for local tests if not set
            dev_key = Fernet.generate_key()
            settings.token_encryption_key = dev_key.decode()
        else:
            raise HTTPException(503, "TOKEN_ENCRYPTION_KEY is not configured")
    try:
        return Fernet(settings.token_encryption_key.encode())
    except Exception:
        raise HTTPException(503, "TOKEN_ENCRYPTION_KEY must be a valid Fernet key")

def encrypt_secret(value: str) -> str:
    return _fernet().encrypt(value.encode()).decode()

def decrypt_secret(value: str) -> str:
    try:
        return _fernet().decrypt(value.encode()).decode()
    except (InvalidToken, ValueError):
        raise HTTPException(503, "Stored LinkedIn token cannot be decrypted")
