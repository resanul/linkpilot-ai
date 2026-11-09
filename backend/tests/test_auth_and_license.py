import pytest
from datetime import datetime, timezone, timedelta
from uuid import uuid4
from app.models import License
from app.security import hash_license_key

def test_missing_google_token(client):
    resp = client.get("/user/profile")
    assert resp.status_code == 401
    assert "Missing Google ID token" in resp.text

def test_invalid_bearer_format(client):
    resp = client.get("/user/profile", headers={"Authorization": "InvalidHeaderFormat"})
    assert resp.status_code == 401

def test_user_registration_and_profile(client, customer_headers):
    resp = client.get("/user/profile", headers=customer_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["email"] == "customer1@example.com"
    assert data["has_active_license"] is False
    assert data["linkedin_connected"] is False

def test_customer_feature_requires_license(client, customer_headers):
    resp = client.get("/posts", headers=customer_headers)
    assert resp.status_code == 403
    assert "active LinkPilot license is required" in resp.text

    resp = client.get("/linkedin/connect", headers=customer_headers)
    assert resp.status_code == 403

def test_license_lifecycle_and_activation(client, customer_headers, customer_b_headers, superadmin_headers):
    # 1. Superadmin issues standard monthly license
    issue_resp = client.post("/admin/licenses?plan=standard&billing_cycle=monthly", headers=superadmin_headers)
    assert issue_resp.status_code == 200
    key = issue_resp.json()["license_key"]
    lic_id = issue_resp.json()["id"]

    # 2. Customer 1 activates the license
    act_resp = client.post("/license/activate", json={"license_key": key}, headers=customer_headers)
    assert act_resp.status_code == 200
    assert act_resp.json()["active"] is True
    assert act_resp.json()["plan"] == "standard"

    # 3. Customer 1 can now access protected features
    posts_resp = client.get("/posts", headers=customer_headers)
    assert posts_resp.status_code == 200
    assert posts_resp.json() == []

    # 4. Customer 2 attempts to use the same key -> 409 conflict
    dup_resp = client.post("/license/activate", json={"license_key": key}, headers=customer_b_headers)
    assert dup_resp.status_code == 409
    assert "already assigned" in dup_resp.text

    # 5. Check license status
    status_resp = client.get("/license/status", headers=customer_headers)
    assert status_resp.status_code == 200
    assert status_resp.json()["active"] is True
    assert status_resp.json()["plan"] == "standard"

def test_expired_license_activation(client, customer_headers, db):
    expired_key = "LP-expired-key-test-12345"
    db.add(License(
        id=str(uuid4()),
        key_hash=hash_license_key(expired_key),
        plan="standard",
        billing_cycle="monthly",
        active=True,
        expires_at=datetime.now(timezone.utc) - timedelta(days=1)
    ))
    db.commit()

    resp = client.post("/license/activate", json={"license_key": expired_key}, headers=customer_headers)
    assert resp.status_code == 403
    assert "expired" in resp.text

def test_revoked_license(client, customer_headers, superadmin_headers):
    # Issue license
    issue = client.post("/admin/licenses?plan=business&billing_cycle=yearly", headers=superadmin_headers).json()
    lic_id = issue["id"]
    key = issue["license_key"]

    # Revoke it before activation
    rev = client.post(f"/admin/licenses/{lic_id}/revoke", headers=superadmin_headers)
    assert rev.status_code == 200
    assert rev.json()["active"] is False

    # Attempt to activate
    act = client.post("/license/activate", json={"license_key": key}, headers=customer_headers)
    assert act.status_code == 403
