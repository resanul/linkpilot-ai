from urllib.parse import urlencode
import secrets
import httpx
from fastapi import HTTPException
from .config import settings

SCOPES = "openid profile w_member_social"

def authorization_url(state: str) -> str:
    if not settings.linkedin_client_id or not settings.linkedin_redirect_uri:
        raise HTTPException(503, "LinkedIn OAuth is not configured")
    params = {"response_type": "code", "client_id": settings.linkedin_client_id,
              "redirect_uri": settings.linkedin_redirect_uri, "scope": SCOPES, "state": state}
    return "https://www.linkedin.com/oauth/v2/authorization?" + urlencode(params)

async def exchange_code(code: str) -> dict:
    if not settings.linkedin_client_id or not settings.linkedin_client_secret:
        raise HTTPException(503, "LinkedIn OAuth is not configured")
    async with httpx.AsyncClient(timeout=20) as client:
        response = await client.post("https://www.linkedin.com/oauth/v2/accessToken", data={
            "grant_type": "authorization_code", "code": code, "redirect_uri": settings.linkedin_redirect_uri,
            "client_id": settings.linkedin_client_id, "client_secret": settings.linkedin_client_secret},
            headers={"Content-Type": "application/x-www-form-urlencoded"})
        if response.is_error:
            raise HTTPException(502, "LinkedIn token exchange failed")
        return response.json()

async def get_profile(access_token: str) -> dict:
    async with httpx.AsyncClient(timeout=20) as client:
        response = await client.get("https://api.linkedin.com/v2/userinfo", headers={"Authorization": f"Bearer {access_token}"})
        if response.is_error:
            raise HTTPException(502, "Could not retrieve LinkedIn member identity")
        return response.json()

async def publish_text_post(access_token: str, person_urn: str, body: str) -> str:
    if not settings.linkedin_version:
        raise HTTPException(503, "LinkedIn API version is not configured")
    payload = {"author": person_urn, "commentary": body, "visibility": "PUBLIC",
      "distribution": {"feedDistribution": "MAIN_FEED", "targetEntities": [], "thirdPartyDistributionChannels": []},
      "lifecycleState": "PUBLISHED", "isReshareDisabledByAuthor": False}
    async with httpx.AsyncClient(timeout=25) as client:
        response = await client.post("https://api.linkedin.com/rest/posts", json=payload, headers={
          "Authorization": f"Bearer {access_token}", "Content-Type": "application/json",
          "X-Restli-Protocol-Version": "2.0.0", "Linkedin-Version": settings.linkedin_version})
        if response.is_error:
            raise HTTPException(502, "LinkedIn post publishing failed")
        return response.headers.get("x-restli-id", "created")
