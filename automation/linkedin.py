"""LinkPilot AI - LinkedIn Official OAuth 2.0 Publisher
Handles author URN resolution and direct post publishing via official LinkedIn APIs.
"""

import os
import requests
from typing import Dict, Tuple, Optional, Any

USERINFO_URL = "https://api.linkedin.com/v2/userinfo"
LEGACY_ME_URL = "https://api.linkedin.com/v2/me"
REST_POSTS_URL = "https://api.linkedin.com/rest/posts"
UGC_POSTS_URL = "https://api.linkedin.com/v2/ugcPosts"


class LinkedInError(Exception):
    pass


def get_author_urn(access_token: str) -> Tuple[str, str]:
    """
    Resolve the author URN and display name for the authenticated LinkedIn user.
    Supports both OpenID Connect (/v2/userinfo) and Legacy Profile (/v2/me).
    Returns: (author_urn, display_name)
    """
    headers = {"Authorization": f"Bearer {access_token}"}

    # 1. Try modern OIDC userinfo (scope: openid profile)
    try:
        res = requests.get(USERINFO_URL, headers=headers, timeout=15)
        if res.status_code == 200:
            data = res.json()
            sub = data.get("sub")
            name = data.get("name", "LinkedIn User")
            if sub:
                return f"urn:li:person:{sub}", name
    except Exception as e:
        print(f"[-] OIDC userinfo check notice: {e}")

    # 2. Fallback to /v2/me (scope: r_liteprofile or r_basicprofile)
    try:
        res = requests.get(LEGACY_ME_URL, headers=headers, timeout=15)
        if res.status_code == 200:
            data = res.json()
            user_id = data.get("id")
            first = data.get("localizedFirstName", "")
            last = data.get("localizedLastName", "")
            name = f"{first} {last}".strip() or "LinkedIn User"
            if user_id:
                return f"urn:li:person:{user_id}", name
    except Exception as e:
        print(f"[-] /v2/me check notice: {e}")

    raise LinkedInError(
        "Could not resolve LinkedIn Author URN. Verify that your access token is valid "
        "and includes 'openid profile' or 'r_liteprofile' scope."
    )


def publish_post(access_token: str, content: str) -> Dict[str, Any]:
    """
    Publish a text post to LinkedIn.
    Uses modern Posts REST API with automatic fallback to UGC Posts API.
    """
    author_urn, name = get_author_urn(access_token)
    print(f"[+] Authenticated as: {name} ({author_urn})")

    # Method 1: Modern LinkedIn REST Posts API (LinkedIn-Version: 202401)
    rest_headers = {
        "Authorization": f"Bearer {access_token}",
        "LinkedIn-Version": "202401",
        "X-Restli-Protocol-Version": "2.0.0",
        "Content-Type": "application/json",
    }

    rest_payload = {
        "author": author_urn,
        "commentary": content,
        "visibility": "PUBLIC",
        "distribution": {
            "feedDistribution": "MAIN_FEED",
            "targetEntities": [],
            "thirdPartyDistributionChannels": [],
        },
        "lifecycleState": "PUBLISHED",
        "isReshareDisabledByAuthor": False,
    }

    try:
        response = requests.post(REST_POSTS_URL, headers=rest_headers, json=rest_payload, timeout=20)
        if response.status_code in (201, 200):
            post_id = response.headers.get("x-restli-id", "")
            if not post_id and response.text:
                try:
                    post_id = response.json().get("id", "")
                except Exception:
                    pass
            post_urn = post_id if post_id else f"urn:li:share:{int(requests.utils.time.time())}"
            return {
                "success": True,
                "post_id": post_urn,
                "author": name,
                "author_urn": author_urn,
                "api_used": "rest_posts",
            }
        else:
            print(f"[-] REST API returned {response.status_code}: {response.text[:120]}. Trying UGC Posts API...")
    except Exception as e:
        print(f"[-] REST API error: {e}. Trying UGC Posts API...")

    # Method 2: Fallback to UGC Posts API (/v2/ugcPosts)
    ugc_headers = {
        "Authorization": f"Bearer {access_token}",
        "X-Restli-Protocol-Version": "2.0.0",
        "Content-Type": "application/json",
    }

    ugc_payload = {
        "author": author_urn,
        "lifecycleState": "PUBLISHED",
        "specificContent": {
            "com.linkedin.ugc.ShareContent": {
                "shareCommentary": {"text": content},
                "shareMediaCategory": "NONE",
            }
        },
        "visibility": {"com.linkedin.ugc.MemberNetworkVisibility": "PUBLIC"},
    }

    ugc_res = requests.post(UGC_POSTS_URL, headers=ugc_headers, json=ugc_payload, timeout=20)
    if ugc_res.status_code in (201, 200):
        data = ugc_res.json()
        post_id = data.get("id", "")
        return {
            "success": True,
            "post_id": post_id,
            "author": name,
            "author_urn": author_urn,
            "api_used": "ugc_posts",
        }

    raise LinkedInError(
        f"LinkedIn publishing failed (HTTP {ugc_res.status_code}): {ugc_res.text}"
    )
