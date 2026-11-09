from contextlib import asynccontextmanager
from uuid import uuid4
from datetime import datetime, timezone, timedelta
import secrets
from fastapi import FastAPI, Depends, HTTPException
from sqlalchemy.orm import Session
from .db import Base, engine, get_db
from .models import User, License, Post, StaffAdmin, OAuthState, LinkedInConnection
from .schemas import LicenseActivate, PostCreate, PostOut, StaffCreate
from .security import verify_google_id_token, hash_license_key
from .config import settings
from .linkedin import authorization_url, exchange_code, get_profile
from .scheduler import start_scheduler
from .security import encrypt_secret
from .ai import generate_cybersecurity_post
import hashlib

@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(bind=engine)
    if settings.app_env.lower() != "test":
        start_scheduler()
    yield

app = FastAPI(title="LinkedIn AI Automation API", version="0.1.0", lifespan=lifespan)

@app.get("/health")
def health():
    return {"status": "ok", "service": "linkpilot-ai", "environment": settings.app_env}

def current_user(claims=Depends(verify_google_id_token), db: Session=Depends(get_db)):
    sub = claims.get("sub")
    if not sub:
        raise HTTPException(401, "Google subject missing")
    user = db.query(User).filter_by(google_sub=sub).first()
    if not user:
        user = User(id=str(uuid4()), google_sub=sub, email=claims.get("email", ""))
        db.add(user); db.commit(); db.refresh(user)
    return user

def require_active_license(user=Depends(current_user), db: Session=Depends(get_db)):
    rows = db.query(License).filter_by(user_id=user.id, active=True).all()
    now = datetime.now(timezone.utc)
    for row in rows:
        expiry = row.expires_at
        if expiry and expiry.tzinfo is None:
            expiry = expiry.replace(tzinfo=timezone.utc)
        if not expiry or expiry > now:
            return user
    raise HTTPException(403, "An active LinkPilot license is required")

@app.post("/license/activate")
def activate_license(payload: LicenseActivate, user=Depends(current_user), db: Session=Depends(get_db)):
    item = db.query(License).filter_by(key_hash=hash_license_key(payload.license_key), active=True).first()
    if not item:
        raise HTTPException(403, "Invalid or inactive license")
    if item.expires_at:
        expiry = item.expires_at
        if expiry.tzinfo is None:
            expiry = expiry.replace(tzinfo=timezone.utc)
        if expiry < datetime.now(timezone.utc):
            raise HTTPException(403, "License expired")
    if item.user_id and item.user_id != user.id:
        raise HTTPException(409, "License already assigned")
    item.user_id = user.id
    item.activated_at = datetime.now(timezone.utc)
    db.commit()
    return {"active": True, "license_id": item.id}


@app.get("/license/status")
def license_status(user=Depends(current_user), db: Session=Depends(get_db)):
    now = datetime.now(timezone.utc)
    rows = db.query(License).filter_by(user_id=user.id, active=True).order_by(License.created_at.desc()).all()
    for row in rows:
        expiry = row.expires_at
        if expiry and expiry.tzinfo is None:
            expiry = expiry.replace(tzinfo=timezone.utc)
        if not expiry or expiry > now:
            return {"active": True, "plan": row.plan, "billing_cycle": row.billing_cycle, "expires_at": row.expires_at}
    return {"active": False}

@app.get("/linkedin/status")
def linkedin_status(user=Depends(require_active_license), db: Session=Depends(get_db)):
    row = db.query(LinkedInConnection).filter_by(user_id=user.id).first()
    if not row:
        return {"connected": False}
    expiry = row.expires_at
    if expiry and expiry.tzinfo is None:
        expiry = expiry.replace(tzinfo=timezone.utc)
    return {"connected": True, "expires_at": row.expires_at, "token_expired": bool(expiry and expiry <= datetime.now(timezone.utc))}

@app.get("/linkedin/connect")
def linkedin_connect(user=Depends(require_active_license), db: Session=Depends(get_db)):
    raw_state = secrets.token_urlsafe(32)
    state_hash = hashlib.sha256(raw_state.encode()).hexdigest()
    db.add(OAuthState(state_hash=state_hash, user_id=user.id,
                      expires_at=datetime.now(timezone.utc) + timedelta(minutes=10)))
    db.commit()
    return {"authorization_url": authorization_url(raw_state), "expires_in": 600}

@app.get("/linkedin/callback")
async def linkedin_callback(code: str | None = None, state: str | None = None, error: str | None = None, db: Session=Depends(get_db)):
    if error:
        raise HTTPException(400, "LinkedIn authorization was not completed")
    if not code or not state:
        raise HTTPException(400, "Missing LinkedIn authorization code or state")
    state_hash = hashlib.sha256(state.encode()).hexdigest()
    state_row = db.query(OAuthState).filter_by(state_hash=state_hash).first()
    if not state_row:
        raise HTTPException(400, "Invalid or already used OAuth state")
    expiry = state_row.expires_at
    if expiry.tzinfo is None:
        expiry = expiry.replace(tzinfo=timezone.utc)
    if expiry <= datetime.now(timezone.utc):
        db.delete(state_row); db.commit()
        raise HTTPException(400, "LinkedIn OAuth state expired; reconnect")
    user_id = state_row.user_id
    db.delete(state_row)
    db.commit()
    # Re-check entitlement at callback time; a license may have been revoked meanwhile.
    entitlement = db.query(License).filter_by(user_id=user_id, active=True).all()
    now = datetime.now(timezone.utc)
    if not any((not x.expires_at) or ((x.expires_at.replace(tzinfo=timezone.utc) if x.expires_at.tzinfo is None else x.expires_at) > now) for x in entitlement):
        raise HTTPException(403, "An active LinkPilot license is required")
    token_data = await exchange_code(code)
    access_token = token_data.get("access_token")
    if not access_token:
        raise HTTPException(502, "LinkedIn did not return an access token")
    profile = await get_profile(access_token)
    subject = profile.get("sub")
    if not subject:
        raise HTTPException(502, "LinkedIn member identity is missing")
    expires_in = int(token_data.get("expires_in", 0) or 0)
    token_expiry = datetime.now(timezone.utc) + timedelta(seconds=expires_in) if expires_in else None
    existing = db.query(LinkedInConnection).filter_by(user_id=user_id).first()
    if existing:
        existing.person_urn = f"urn:li:person:{subject}"
        existing.access_token_encrypted = encrypt_secret(access_token)
        existing.expires_at = token_expiry
        existing.updated_at = datetime.now(timezone.utc)
    else:
        db.add(LinkedInConnection(id=str(uuid4()), user_id=user_id,
            person_urn=f"urn:li:person:{subject}", access_token_encrypted=encrypt_secret(access_token),
            expires_at=token_expiry))
    db.commit()
    return {"connected": True, "message": "LinkedIn account connected. Return to LinkPilot AI."}

@app.get("/posts", response_model=list[PostOut])
def list_posts(user=Depends(require_active_license), db: Session=Depends(get_db)):
    return db.query(Post).filter_by(user_id=user.id).order_by(Post.created_at.desc()).limit(100).all()

@app.post("/posts", response_model=PostOut)
def create_post(payload: PostCreate, user=Depends(require_active_license), db: Session=Depends(get_db)):
    if not payload.approval_required and not payload.scheduled_at:
        raise HTTPException(400, "scheduled_at is required for automatic publishing")
    scheduled = payload.scheduled_at
    if scheduled and scheduled.tzinfo is None:
        scheduled = scheduled.replace(tzinfo=timezone.utc)
    if scheduled and scheduled <= datetime.now(timezone.utc):
        raise HTTPException(400, "scheduled_at must be in the future")
    post = Post(id=str(uuid4()), user_id=user.id, body=payload.body,
                status="pending_approval" if payload.approval_required else "scheduled",
                approval_required=payload.approval_required, scheduled_at=scheduled)
    db.add(post); db.commit(); db.refresh(post)
    return post

@app.post("/posts/{post_id}/approve")
def approve_post(post_id: str, user=Depends(require_active_license), db: Session=Depends(get_db)):
    post = db.query(Post).filter_by(id=post_id, user_id=user.id).first()
    if not post: raise HTTPException(404, "Post not found")
    if post.status != "pending_approval": raise HTTPException(409, "Post is not awaiting approval")
    post.status = "scheduled"
    if not post.scheduled_at:
        post.scheduled_at = datetime.now(timezone.utc)
    db.commit()
    return {"id": post.id, "status": post.status}



@app.post("/ai/generate")
async def ai_generate(topic: str = "cybersecurity", user=Depends(require_active_license)):
    content = await generate_cybersecurity_post(topic)
    return {"content": content, "language": "en"}

def _super_admin_emails():
    return {x.strip().lower() for x in settings.admin_emails.split(",") if x.strip()}

def current_admin(user=Depends(current_user), db: Session = Depends(get_db)):
    email = (user.email or "").lower()
    if email in _super_admin_emails():
        user.admin_role = "super_admin"
        return user
    staff = db.query(StaffAdmin).filter_by(email=email, active=True).first()
    if staff:
        user.admin_role = "staff"
        return user
    raise HTTPException(403, "Admin access required")

def current_super_admin(admin=Depends(current_admin)):
    if getattr(admin, "admin_role", "") != "super_admin":
        raise HTTPException(403, "Super Admin permission required")
    return admin

@app.get("/admin/overview")
def admin_overview(admin=Depends(current_admin), db: Session = Depends(get_db)):
    return {
        "customers": db.query(User).count(),
        "active_licenses": db.query(License).filter_by(active=True).count(),
        "assigned_licenses": db.query(License).filter(License.user_id.isnot(None)).count(),
        "posts": db.query(Post).count(),
        "admin_role": admin.admin_role,
    }

@app.get("/admin/licenses")
def admin_list_licenses(admin=Depends(current_admin), db: Session = Depends(get_db)):
    rows = db.query(License).order_by(License.created_at.desc()).limit(500).all()
    return [{
        "id": x.id, "plan": x.plan, "billing_cycle": x.billing_cycle,
        "active": x.active, "assigned": bool(x.user_id),
        "expires_at": x.expires_at, "created_at": x.created_at,
        "max_devices": x.max_devices
    } for x in rows]

@app.post("/admin/licenses")
def admin_create_license(
    plan: str = "standard",
    billing_cycle: str = "monthly",
    admin=Depends(current_admin),
    db: Session = Depends(get_db)
):
    # Manual issuance only. Payment automation is intentionally not enabled.
    if plan not in {"standard", "pro", "business"}:
        raise HTTPException(400, "Unsupported plan")
    if billing_cycle not in {"monthly", "yearly", "lifetime"}:
        raise HTTPException(400, "Unsupported billing cycle")
    days = {"monthly": 30, "yearly": 365, "lifetime": None}[billing_cycle]
    expiry = datetime.now(timezone.utc) + timedelta(days=days) if days else None
    raw_key = "LP-" + secrets.token_urlsafe(24)
    item = License(
        id=str(uuid4()), key_hash=hash_license_key(raw_key),
        plan=plan, billing_cycle=billing_cycle, active=True,
        expires_at=expiry, max_devices=1, user_id=None
    )
    db.add(item)
    db.commit()
    db.refresh(item)
    return {
        "id": item.id, "license_key": raw_key, "plan": item.plan,
        "billing_cycle": item.billing_cycle, "expires_at": item.expires_at,
        "issued_by": admin.admin_role,
        "note": "Copy this key now; it cannot be retrieved again."
    }

@app.post("/admin/licenses/{license_id}/revoke")
def admin_revoke_license(license_id: str, admin=Depends(current_super_admin),
                         db: Session = Depends(get_db)):
    item = db.query(License).filter_by(id=license_id).first()
    if not item:
        raise HTTPException(404, "License not found")
    item.active = False
    db.commit()
    return {"id": item.id, "active": False}

@app.get("/admin/customers")
def admin_list_customers(admin=Depends(current_admin), db: Session = Depends(get_db)):
    rows = db.query(User).order_by(User.created_at.desc()).limit(500).all()
    return [{"id": x.id, "email": x.email, "created_at": x.created_at}
            for x in rows]

@app.get("/admin/staff")
def admin_list_staff(admin=Depends(current_super_admin), db: Session = Depends(get_db)):
    rows = db.query(StaffAdmin).order_by(StaffAdmin.created_at.desc()).all()
    return [{"id": x.id, "email": x.email, "active": x.active,
             "created_at": x.created_at} for x in rows]

@app.post("/admin/staff")
def admin_add_staff(payload: StaffCreate, admin=Depends(current_super_admin),
                    db: Session = Depends(get_db)):
    email = payload.email.strip().lower()
    if email in _super_admin_emails():
        raise HTTPException(409, "This email is already a Super Admin")
    existing = db.query(StaffAdmin).filter_by(email=email).first()
    if existing:
        existing.active = True
        db.commit()
        return {"id": existing.id, "email": existing.email, "active": True}
    item = StaffAdmin(id=str(uuid4()), email=email, active=True)
    db.add(item)
    db.commit()
    db.refresh(item)
    return {"id": item.id, "email": item.email, "active": item.active}

@app.post("/admin/staff/{staff_id}/revoke")
def admin_revoke_staff(staff_id: str, admin=Depends(current_super_admin),
                       db: Session = Depends(get_db)):
    item = db.query(StaffAdmin).filter_by(id=staff_id).first()
    if not item:
        raise HTTPException(404, "Staff account not found")
    item.active = False
    db.commit()
    return {"id": item.id, "active": False}
