import os
from cryptography.fernet import Fernet

# Set test environment before any app imports
os.environ["APP_ENV"] = "test"
os.environ["DATABASE_URL"] = "sqlite:///./test_linkpilot.db"
os.environ["LICENSE_SIGNING_SECRET"] = "test-secret-key-32-bytes-minimum-length-for-hmac-sha256"
os.environ["TOKEN_ENCRYPTION_KEY"] = Fernet.generate_key().decode()
os.environ["ADMIN_EMAILS"] = "superadmin@linkpilot.io,owner@linkpilot.io"

import pytest
from datetime import datetime, timezone, timedelta
from uuid import uuid4
from fastapi.testclient import TestClient

from app.config import settings
settings.database_url = "sqlite:///./test_linkpilot.db"
settings.app_env = "test"

from app.db import Base, engine, SessionLocal, get_db
from app.main import app
from app.models import User, License, StaffAdmin, LinkedInConnection, Post
from app.security import hash_license_key, encrypt_secret

@pytest.fixture(scope="session", autouse=True)
def setup_test_db():
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)
    if os.path.exists("./test_linkpilot.db"):
        try:
            os.remove("./test_linkpilot.db")
        except OSError:
            pass

@pytest.fixture
def db():
    database = SessionLocal()
    try:
        yield database
    finally:
        database.close()

@pytest.fixture
def client():
    return TestClient(app)

@pytest.fixture
def superadmin_headers():
    return {"Authorization": "Bearer test-token-superadmin@linkpilot.io"}

@pytest.fixture
def staff_headers(db):
    email = "staff1@linkpilot.io"
    existing = db.query(StaffAdmin).filter_by(email=email).first()
    if not existing:
        db.add(StaffAdmin(id=str(uuid4()), email=email, active=True))
        db.commit()
    return {"Authorization": f"Bearer test-token-{email}"}

@pytest.fixture
def customer_headers(db):
    email = "customer1@example.com"
    return {"Authorization": f"Bearer test-token-{email}"}

@pytest.fixture
def customer_b_headers(db):
    email = "customer2@example.com"
    return {"Authorization": f"Bearer test-token-{email}"}

@pytest.fixture
def activated_customer_headers(client, customer_headers, superadmin_headers):
    resp = client.post("/admin/licenses?plan=pro&billing_cycle=monthly", headers=superadmin_headers)
    key = resp.json()["license_key"]
    act_resp = client.post("/license/activate", json={"license_key": key}, headers=customer_headers)
    assert act_resp.status_code == 200
    return customer_headers
