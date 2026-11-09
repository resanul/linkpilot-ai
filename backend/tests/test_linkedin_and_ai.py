import pytest
from unittest.mock import patch, AsyncMock
from datetime import datetime, timezone, timedelta
from app.models import OAuthState, LinkedInConnection
from app.security import decrypt_secret
import hashlib

def test_linkedin_connect_flow(client, activated_customer_headers, db):
    # Configure mock LinkedIn client ID
    with patch("app.linkedin.settings.linkedin_client_id", "test-li-client-id"), \
         patch("app.linkedin.settings.linkedin_redirect_uri", "https://api.test/linkedin/callback"):
        resp = client.get("/linkedin/connect", headers=activated_customer_headers)
        assert resp.status_code == 200
        data = resp.json()
        assert "authorization_url" in data
        assert "https://www.linkedin.com/oauth/v2/authorization" in data["authorization_url"]
        assert "state=" in data["authorization_url"]

def test_linkedin_callback_validation_and_replay(client, activated_customer_headers, db):
    # 1. Callback without code/state -> 400
    resp = client.get("/linkedin/callback")
    assert resp.status_code == 400

    # 2. Callback with non-existent state -> 400
    resp = client.get("/linkedin/callback?code=mock-code&state=fake-state-12345")
    assert resp.status_code == 400
    assert "Invalid or already used" in resp.text

    # 3. Create a valid state in DB
    raw_state = "test-single-use-state-999"
    state_hash = hashlib.sha256(raw_state.encode()).hexdigest()

    # Get customer ID
    profile = client.get("/user/profile", headers=activated_customer_headers).json()
    user_id = profile["id"]

    db.add(OAuthState(
        state_hash=state_hash,
        user_id=user_id,
        expires_at=datetime.now(timezone.utc) + timedelta(minutes=10)
    ))
    db.commit()

    # Mock LinkedIn exchange and userinfo
    mock_token_data = {"access_token": "AQX-mock-linkedin-access-token", "expires_in": 5184000}
    mock_profile_data = {"sub": "li-member-777", "name": "Alice Security"}

    with patch("app.main.exchange_code", new_callable=AsyncMock) as mock_exch, \
         patch("app.main.get_profile", new_callable=AsyncMock) as mock_prof:
        mock_exch.return_value = mock_token_data
        mock_prof.return_value = mock_profile_data

        callback_resp = client.get(f"/linkedin/callback?code=valid-code&state={raw_state}")
        assert callback_resp.status_code == 200
        assert callback_resp.json()["connected"] is True
        assert callback_resp.json()["profile_name"] == "Alice Security"

        # Verify token was encrypted in DB
        conn = db.query(LinkedInConnection).filter_by(user_id=user_id).first()
        assert conn is not None
        assert conn.person_urn == "urn:li:person:li-member-777"
        assert conn.profile_name == "Alice Security"
        assert decrypt_secret(conn.access_token_encrypted) == "AQX-mock-linkedin-access-token"

        # 4. Replay attack: calling again with same state -> 400 Invalid or already used
        replay_resp = client.get(f"/linkedin/callback?code=valid-code&state={raw_state}")
        assert replay_resp.status_code == 400
        assert "Invalid or already used" in replay_resp.text

def test_ai_generate_and_regenerate(client, activated_customer_headers):
    mock_ai_output = (
        "Implementing zero-trust architecture requires continuous verification across identities, "
        "devices, and networks. Micro-segmentation significantly reduces blast radiuses during an "
        "active breach. #CyberSecurity #ZeroTrust #CloudSecurity #InfoSec"
    )

    with patch("app.ai.GeminiProvider._call_gemini_with_retry", new_callable=AsyncMock) as mock_call:
        mock_call.return_value = mock_ai_output

        # Generate
        gen_resp = client.post(
            "/ai/generate",
            json={"topic": "Zero Trust Architecture"},
            headers=activated_customer_headers
        )
        assert gen_resp.status_code == 200
        data = gen_resp.json()
        assert "zero-trust architecture" in data["content"].lower()
        assert data["topic"] == "Zero Trust Architecture"

        # Regenerate
        regen_resp = client.post(
            "/ai/regenerate",
            json={
                "original_body": data["content"],
                "topic": "Zero Trust Architecture",
                "instructions": "Make it more focused on MITRE ATT&CK mapping"
            },
            headers=activated_customer_headers
        )
        assert regen_resp.status_code == 200
        assert "content" in regen_resp.json()

def test_linkedin_connect_manual(client, activated_customer_headers, db):
    mock_profile = {"sub": "manual-sub-123", "name": "Bob Cybersecurity"}
    with patch("app.main.get_profile", new_callable=AsyncMock) as mock_p:
        mock_p.return_value = mock_profile

        resp = client.post(
            "/linkedin/connect-manual",
            json={"access_token": "AQX-manual-access-token-123456789"},
            headers=activated_customer_headers
        )
        assert resp.status_code == 200
        assert resp.json()["connected"] is True
        assert resp.json()["profile_name"] == "Bob Cybersecurity"
