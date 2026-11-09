import pytest
from datetime import datetime, timezone, timedelta
from uuid import uuid4

def test_post_creation_and_lifecycle(client, activated_customer_headers):
    # Create draft requiring approval
    create_resp = client.post(
        "/posts",
        json={
            "body": "Zero-trust architecture is essential for modern cloud environments. #CloudSecurity #InfoSec",
            "title": "Zero Trust Overview",
            "topic": "Cloud security",
            "approval_required": True
        },
        headers=activated_customer_headers
    )
    assert create_resp.status_code == 200
    post = create_resp.json()
    post_id = post["id"]
    assert post["status"] == "pending_approval"
    assert post["approval_required"] is True

    # Approve post
    app_resp = client.post(f"/posts/{post_id}/approve", headers=activated_customer_headers)
    assert app_resp.status_code == 200
    assert app_resp.json()["status"] == "scheduled"

    # Edit post
    update_resp = client.put(
        f"/posts/{post_id}",
        json={"body": "Zero-trust architecture updated with MITRE ATT&CK alignment. #CloudSecurity #MITRE"},
        headers=activated_customer_headers
    )
    assert update_resp.status_code == 200
    assert "MITRE" in update_resp.json()["body"]

    # Delete post
    del_resp = client.delete(f"/posts/{post_id}", headers=activated_customer_headers)
    assert del_resp.status_code == 200
    assert del_resp.json()["deleted"] is True

def test_tenant_isolation_and_idor_protection(client, activated_customer_headers, customer_b_headers, superadmin_headers):
    # Activate customer B
    lic_resp = client.post("/admin/licenses?plan=standard&billing_cycle=monthly", headers=superadmin_headers).json()
    client.post("/license/activate", json={"license_key": lic_resp["license_key"]}, headers=customer_b_headers)

    # Customer A creates post
    post_a = client.post(
        "/posts",
        json={
            "body": "Customer A confidential cybersecurity strategy. #InfoSec",
            "approval_required": True
        },
        headers=activated_customer_headers
    ).json()
    post_a_id = post_a["id"]

    # Customer B attempts to list posts (should NOT see post A)
    list_b = client.get("/posts", headers=customer_b_headers).json()
    assert not any(p["id"] == post_a_id for p in list_b)

    # Customer B attempts to approve post A -> 404 Not Found
    approve_attempt = client.post(f"/posts/{post_a_id}/approve", headers=customer_b_headers)
    assert approve_attempt.status_code == 404

    # Customer B attempts to edit post A -> 404 Not Found
    edit_attempt = client.put(f"/posts/{post_a_id}", json={"body": "Hacked content"}, headers=customer_b_headers)
    assert edit_attempt.status_code == 404

    # Customer B attempts to delete post A -> 404 Not Found
    delete_attempt = client.delete(f"/posts/{post_a_id}", headers=customer_b_headers)
    assert delete_attempt.status_code == 404

def test_post_sync_endpoint(client, activated_customer_headers):
    client_uuid = str(uuid4())
    sync_payload = {
        "posts": [
            {
                "client_id": client_uuid,
                "title": "Offline Created Post",
                "topic": "Incident response",
                "body": "Incident response tabletop exercise best practices. #IncidentResponse #SOC",
                "status": "pending_approval",
                "approval_required": True
            }
        ]
    }
    sync_resp = client.post("/posts/sync", json=sync_payload, headers=activated_customer_headers)
    assert sync_resp.status_code == 200
    data = sync_resp.json()
    assert "synced_posts" in data
    assert any(p["client_id"] == client_uuid for p in data["synced_posts"])

    # Syncing again should deduplicate (idempotent)
    sync_resp_2 = client.post("/posts/sync", json=sync_payload, headers=activated_customer_headers)
    assert sync_resp_2.status_code == 200
    matches = [p for p in sync_resp_2.json()["synced_posts"] if p["client_id"] == client_uuid]
    assert len(matches) == 1
