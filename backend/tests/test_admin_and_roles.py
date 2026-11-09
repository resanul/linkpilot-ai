import pytest

def test_unauthorized_user_blocked_from_admin(client, customer_headers):
    resp = client.get("/admin/overview", headers=customer_headers)
    assert resp.status_code == 403
    assert "Admin access required" in resp.text

    resp = client.get("/admin/licenses", headers=customer_headers)
    assert resp.status_code == 403

    resp = client.post("/admin/licenses", headers=customer_headers)
    assert resp.status_code == 403

def test_superadmin_capabilities(client, superadmin_headers):
    # Overview
    overview = client.get("/admin/overview", headers=superadmin_headers)
    assert overview.status_code == 200
    data = overview.json()
    assert "customers" in data
    assert "active_licenses" in data
    assert data["admin_role"] == "super_admin"

    # Create license
    new_lic = client.post("/admin/licenses?plan=business&billing_cycle=lifetime", headers=superadmin_headers)
    assert new_lic.status_code == 200
    assert new_lic.json()["plan"] == "business"
    assert new_lic.json()["billing_cycle"] == "lifetime"
    assert new_lic.json()["expires_at"] is None

    # Revoke license
    lic_id = new_lic.json()["id"]
    rev = client.post(f"/admin/licenses/{lic_id}/revoke", headers=superadmin_headers)
    assert rev.status_code == 200
    assert rev.json()["active"] is False

    # Manage Staff
    add_staff = client.post("/admin/staff", json={"email": "newanalyst@linkpilot.io"}, headers=superadmin_headers)
    assert add_staff.status_code == 200
    staff_id = add_staff.json()["id"]
    assert add_staff.json()["email"] == "newanalyst@linkpilot.io"

    # Revoke Staff
    rev_staff = client.post(f"/admin/staff/{staff_id}/revoke", headers=superadmin_headers)
    assert rev_staff.status_code == 200
    assert rev_staff.json()["active"] is False

    # View audit logs
    audit = client.get("/admin/audit-logs", headers=superadmin_headers)
    assert audit.status_code == 200
    assert len(audit.json()) > 0

def test_staff_admin_role_boundaries(client, staff_headers):
    # Staff CAN view overview
    overview = client.get("/admin/overview", headers=staff_headers)
    assert overview.status_code == 200
    assert overview.json()["admin_role"] == "staff"

    # Staff CAN view licenses and create licenses
    lic_resp = client.get("/admin/licenses", headers=staff_headers)
    assert lic_resp.status_code == 200

    create_resp = client.post("/admin/licenses?plan=standard&billing_cycle=monthly", headers=staff_headers)
    assert create_resp.status_code == 200
    lic_id = create_resp.json()["id"]

    # Staff CANNOT revoke licenses
    rev_resp = client.post(f"/admin/licenses/{lic_id}/revoke", headers=staff_headers)
    assert rev_resp.status_code == 403
    assert "Super Admin permission required" in rev_resp.text

    # Staff CANNOT view staff
    staff_view = client.get("/admin/staff", headers=staff_headers)
    assert staff_view.status_code == 403

    # Staff CANNOT add staff
    staff_add = client.post("/admin/staff", json={"email": "someone@example.com"}, headers=staff_headers)
    assert staff_add.status_code == 403

    # Staff CANNOT view audit logs
    audit_view = client.get("/admin/audit-logs", headers=staff_headers)
    assert audit_view.status_code == 403
