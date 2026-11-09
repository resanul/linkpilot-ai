import hashlib
import logging
import secrets
from contextlib import asynccontextmanager
from datetime import datetime, timezone, timedelta
from uuid import uuid4

from fastapi import FastAPI, Depends, HTTPException, Request, Response, Header
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

from .config import settings
from .db import Base, engine, get_db
from .models import User, License, Post, StaffAdmin, OAuthState, LinkedInConnection, AuditLog
from .schemas import (
    LicenseActivate, PostCreate, PostUpdate, PostOut,
    PostSyncRequest, PostSyncResponse, StaffCreate,
    AIGenerateRequest, AIRegenerateRequest, UserProfileOut, AuditLogOut,
    LinkedInManualConnect
)
from .security import verify_google_id_token, hash_license_key, encrypt_secret
from .linkedin import authorization_url, exchange_code, get_profile
from .scheduler import start_scheduler
from .ai import generate_cybersecurity_post, regenerate_cybersecurity_post

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("linkpilot.api")

limiter = Limiter(key_func=get_remote_address, enabled=(settings.app_env.lower() != "test"))

@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(bind=engine)
    if settings.app_env.lower() != "test":
        start_scheduler()
    yield

app = FastAPI(
    title="LinkPilot AI Automation API",
    version="1.0.0",
    description="Commercial Multi-Customer LinkedIn Cybersecurity Automation Backend",
    lifespan=lifespan
)

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# CORS Configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def log_audit(db: Session, actor_id: str | None, actor_email: str | None,
              action: str, target_type: str | None = None,
              target_id: str | None = None, details: str | None = None):
    audit = AuditLog(
        id=str(uuid4()),
        actor_id=actor_id,
        actor_email=actor_email,
        action=action,
        target_type=target_type,
        target_id=target_id,
        details=details
    )
    db.add(audit)
    db.commit()

@app.get("/health")
def health():
    return {
        "status": "ok",
        "service": "linkpilot-ai",
        "version": "1.0.0",
        "environment": settings.app_env
    }

def _super_admin_emails() -> set[str]:
    return {x.strip().lower() for x in settings.admin_emails.split(",") if x.strip()}

def resolve_actor(
    request: Request,
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db)
) -> User:
    admin_pin = request.headers.get("X-Admin-Pin", "").strip()
    if admin_pin and admin_pin == settings.master_admin_pin:
        user = db.query(User).filter_by(email="admin@linkpilot.ai").first()
        if not user:
            user = User(id=str(uuid4()), google_sub="master-admin-system", email="admin@linkpilot.ai", role="super_admin")
            db.add(user)
            db.commit()
            db.refresh(user)
        setattr(user, "admin_role", "super_admin")
        return user

    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(401, "Missing Google ID token or Master Admin PIN")

    claims = verify_google_id_token(authorization)
    sub = claims.get("sub")
    if not sub:
        raise HTTPException(401, "Google subject missing")
    email = claims.get("email", "").strip().lower()
    user = db.query(User).filter_by(google_sub=sub).first()
    if not user:
        user = User(id=str(uuid4()), google_sub=sub, email=email)
        db.add(user)
        db.commit()
        db.refresh(user)
        log_audit(db, user.id, email, "USER_REGISTERED", "user", user.id, "Registered via Google OAuth")
    elif user.email != email and email:
        user.email = email
        db.commit()
    return user

def current_user(user: User = Depends(resolve_actor)) -> User:
    return user

def require_active_license(user: User = Depends(current_user), db: Session = Depends(get_db)) -> User:
    if getattr(user, "admin_role", None) == "super_admin" or (user.email or "").lower().strip() in _super_admin_emails():
        return user
    rows = db.query(License).filter_by(user_id=user.id, active=True).all()
    now = datetime.now(timezone.utc)
    for row in rows:
        expiry = row.expires_at
        if expiry and expiry.tzinfo is None:
            expiry = expiry.replace(tzinfo=timezone.utc)
        if not expiry or expiry > now:
            return user
    raise HTTPException(403, "An active LinkPilot license is required")

def current_admin(user: User = Depends(resolve_actor), db: Session = Depends(get_db)) -> User:
    if getattr(user, "admin_role", None) == "super_admin":
        return user
    email = (user.email or "").lower().strip()
    if email in _super_admin_emails():
        setattr(user, "admin_role", "super_admin")
        return user
    staff = db.query(StaffAdmin).filter_by(email=email, active=True).first()
    if staff:
        setattr(user, "admin_role", "staff")
        return user
    raise HTTPException(403, "Admin access required. Provide valid admin credentials or Master Admin PIN.")

def current_super_admin(admin: User = Depends(current_admin)) -> User:
    if getattr(admin, "admin_role", "") != "super_admin":
        raise HTTPException(403, "Super Admin permission required")
    return admin

# --- User Profile & Status ---

@app.get("/user/profile", response_model=UserProfileOut)
def get_user_profile(user: User = Depends(current_user), db: Session = Depends(get_db)):
    email = (user.email or "").lower().strip()
    admin_role = getattr(user, "admin_role", None)
    if email in _super_admin_emails():
        admin_role = "super_admin"
    elif not admin_role and db.query(StaffAdmin).filter_by(email=email, active=True).first():
        admin_role = "staff"

    now = datetime.now(timezone.utc)
    lic = db.query(License).filter_by(user_id=user.id, active=True).order_by(License.created_at.desc()).first()
    has_active_lic = False
    plan, cycle, expires_at = None, None, None
    days_remaining = None
    if admin_role == "super_admin":
        has_active_lic = True
        plan = "enterprise"
        cycle = "lifetime"
        days_remaining = None
    elif lic:
        exp = lic.expires_at
        if exp and exp.tzinfo is None:
            exp = exp.replace(tzinfo=timezone.utc)
        if not exp or exp > now:
            has_active_lic = True
            plan, cycle, expires_at = lic.plan, lic.billing_cycle, lic.expires_at
            if exp:
                diff = (exp - now).days + 1
                days_remaining = max(0, diff)

    conn = db.query(LinkedInConnection).filter_by(user_id=user.id).first()
    linkedin_connected = False
    profile_name = None
    if conn:
        c_exp = conn.expires_at
        if c_exp and c_exp.tzinfo is None:
            c_exp = c_exp.replace(tzinfo=timezone.utc)
        linkedin_connected = not (c_exp and c_exp <= now)
        profile_name = conn.profile_name

    return UserProfileOut(
        id=user.id,
        email=user.email,
        role=user.role,
        admin_role=admin_role,
        has_active_license=has_active_lic,
        license_plan=plan,
        license_cycle=cycle,
        license_expires_at=expires_at,
        days_remaining=days_remaining,
        linkedin_connected=linkedin_connected,
        linkedin_profile_name=profile_name,
        created_at=user.created_at
    )

# --- License Activation & Status ---

@app.post("/license/activate")
@limiter.limit("10/minute")
def activate_license(request: Request, payload: LicenseActivate, user: User = Depends(current_user), db: Session = Depends(get_db)):
    item = db.query(License).filter_by(key_hash=hash_license_key(payload.license_key), active=True).first()
    if not item:
        raise HTTPException(403, "Invalid or inactive license key")
    if item.user_id and item.user_id != user.id:
        raise HTTPException(409, "License key is already assigned to another customer")

    now = datetime.now(timezone.utc)

    # Check pre-existing expiry if already set
    if item.expires_at:
        exp = item.expires_at if item.expires_at.tzinfo else item.expires_at.replace(tzinfo=timezone.utc)
        if exp < now:
            raise HTTPException(403, "This license key has expired")
    elif item.activated_at is None:
        duration_days = 30
        if item.billing_cycle:
            if item.billing_cycle == "yearly":
                duration_days = 365
            elif item.billing_cycle == "quarterly":
                duration_days = 90
            elif item.billing_cycle == "lifetime":
                duration_days = None
            elif "_days" in item.billing_cycle:
                try:
                    duration_days = int(item.billing_cycle.split("_")[0])
                except Exception:
                    duration_days = 30
        if duration_days:
            item.expires_at = now + timedelta(days=duration_days)
        item.activated_at = now

    item.user_id = user.id
    db.commit()

    days_rem = None
    if item.expires_at:
        exp = item.expires_at if item.expires_at.tzinfo else item.expires_at.replace(tzinfo=timezone.utc)
        days_rem = max(0, (exp - now).days + 1)

    log_audit(db, user.id, user.email, "LICENSE_ACTIVATED", "license", item.id, f"Plan: {item.plan}, Days: {days_rem}")
    return {
        "active": True,
        "license_id": item.id,
        "plan": item.plan,
        "billing_cycle": item.billing_cycle,
        "days_remaining": days_rem,
        "expires_at": item.expires_at
    }

@app.get("/license/status")
def license_status(user: User = Depends(current_user), db: Session = Depends(get_db)):
    now = datetime.now(timezone.utc)
    rows = db.query(License).filter_by(user_id=user.id, active=True).order_by(License.created_at.desc()).all()
    for row in rows:
        expiry = row.expires_at
        if expiry and expiry.tzinfo is None:
            expiry = expiry.replace(tzinfo=timezone.utc)
        if not expiry or expiry > now:
            return {
                "active": True,
                "plan": row.plan,
                "billing_cycle": row.billing_cycle,
                "expires_at": row.expires_at
            }
    return {"active": False}

# --- LinkedIn OAuth & Connection ---

@app.get("/linkedin/status")
def linkedin_status(user: User = Depends(require_active_license), db: Session = Depends(get_db)):
    row = db.query(LinkedInConnection).filter_by(user_id=user.id).first()
    if not row:
        return {"connected": False}
    expiry = row.expires_at
    if expiry and expiry.tzinfo is None:
        expiry = expiry.replace(tzinfo=timezone.utc)
    token_expired = bool(expiry and expiry <= datetime.now(timezone.utc))
    return {
        "connected": not token_expired,
        "profile_name": row.profile_name,
        "person_urn": row.person_urn,
        "expires_at": row.expires_at,
        "token_expired": token_expired
    }

@app.get("/linkedin/connect")
@limiter.limit("5/minute")
def linkedin_connect(request: Request, user: User = Depends(require_active_license), db: Session = Depends(get_db)):
    raw_state = secrets.token_urlsafe(32)
    state_hash = hashlib.sha256(raw_state.encode()).hexdigest()
    db.add(OAuthState(
        state_hash=state_hash,
        user_id=user.id,
        expires_at=datetime.now(timezone.utc) + timedelta(minutes=10)
    ))
    db.commit()
    return {"authorization_url": authorization_url(raw_state), "expires_in": 600}

@app.get("/linkedin/callback")
async def linkedin_callback(code: str | None = None, state: str | None = None, error: str | None = None, db: Session = Depends(get_db)):
    if error:
        raise HTTPException(400, f"LinkedIn authorization was not completed: {error}")
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
        db.delete(state_row)
        db.commit()
        raise HTTPException(400, "LinkedIn OAuth state expired; please reconnect")

    user_id = state_row.user_id
    db.delete(state_row)
    db.commit()

    # Re-check active license entitlement
    entitlement = db.query(License).filter_by(user_id=user_id, active=True).all()
    now = datetime.now(timezone.utc)
    has_active = any(
        (not x.expires_at) or ((x.expires_at.replace(tzinfo=timezone.utc) if x.expires_at.tzinfo is None else x.expires_at) > now)
        for x in entitlement
    )
    if not has_active:
        raise HTTPException(403, "An active LinkPilot license is required")

    token_data = await exchange_code(code)
    access_token = token_data.get("access_token")
    if not access_token:
        raise HTTPException(502, "LinkedIn did not return an access token")

    profile = await get_profile(access_token)
    subject = profile.get("sub")
    if not subject:
        raise HTTPException(502, "LinkedIn member identity is missing")

    profile_name = profile.get("name") or f"{profile.get('given_name', '')} {profile.get('family_name', '')}".strip() or "LinkedIn Member"
    expires_in = int(token_data.get("expires_in", 0) or 0)
    token_expiry = datetime.now(timezone.utc) + timedelta(seconds=expires_in) if expires_in else None

    existing = db.query(LinkedInConnection).filter_by(user_id=user_id).first()
    if existing:
        existing.person_urn = f"urn:li:person:{subject}"
        existing.profile_name = profile_name
        existing.access_token_encrypted = encrypt_secret(access_token)
        existing.expires_at = token_expiry
        existing.updated_at = datetime.now(timezone.utc)
    else:
        db.add(LinkedInConnection(
            id=str(uuid4()),
            user_id=user_id,
            person_urn=f"urn:li:person:{subject}",
            profile_name=profile_name,
            access_token_encrypted=encrypt_secret(access_token),
            expires_at=token_expiry
        ))
    db.commit()

    log_audit(db, user_id, None, "LINKEDIN_CONNECTED", "linkedin_connection", subject, f"Connected as {profile_name}")
    return {"connected": True, "message": "LinkedIn account connected successfully. Return to LinkPilot AI.", "profile_name": profile_name}

@app.post("/linkedin/disconnect")
def linkedin_disconnect(user: User = Depends(require_active_license), db: Session = Depends(get_db)):
    conn = db.query(LinkedInConnection).filter_by(user_id=user.id).first()
    if conn:
        db.delete(conn)
        db.commit()
        log_audit(db, user.id, user.email, "LINKEDIN_DISCONNECTED", "linkedin_connection", user.id, "Disconnected account")
    return {"connected": False, "message": "LinkedIn account disconnected"}

@app.post("/linkedin/connect-manual")
async def linkedin_connect_manual(payload: LinkedInManualConnect, user: User = Depends(require_active_license), db: Session = Depends(get_db)):
    token = payload.access_token.strip()
    profile_name = "Personal Profile"
    subject = f"manual_{user.id[:8]}"

    try:
        profile = await get_profile(token)
        first = profile.get("localizedFirstName", "")
        last = profile.get("localizedLastName", "")
        profile_name = profile.get("name") or f"{first} {last}".strip() or "LinkedIn Member"
        subject = profile.get("sub") or profile.get("id") or subject
    except Exception as e:
        logger.warning("Could not fetch remote profile during manual connect: %s. Using default profile.", e)

    enc_token = encrypt_secret(token)
    now = datetime.now(timezone.utc)
    conn = db.query(LinkedInConnection).filter_by(user_id=user.id).first()

    if not conn:
        conn = LinkedInConnection(
            id=str(uuid4()),
            user_id=user.id,
            encrypted_access_token=enc_token,
            person_urn=f"urn:li:person:{subject}",
            profile_name=profile_name,
            expires_at=now + timedelta(days=60),
            created_at=now,
            updated_at=now
        )
        db.add(conn)
    else:
        conn.encrypted_access_token = enc_token
        conn.person_urn = f"urn:li:person:{subject}"
        conn.profile_name = profile_name
        conn.expires_at = now + timedelta(days=60)
        conn.updated_at = now

    log_audit(db, user.id, user.email, "LINKEDIN_CONNECTED_MANUAL", "linkedin_connection", subject, f"Connected as {profile_name}")
    db.commit()
    return {"connected": True, "message": f"LinkedIn connected successfully as {profile_name}.", "profile_name": profile_name}

# --- Post Management & Cloud History ---

@app.get("/posts", response_model=list[PostOut])
def list_posts(status: str | None = None, limit: int = 100, user: User = Depends(require_active_license), db: Session = Depends(get_db)):
    query = db.query(Post).filter_by(user_id=user.id)
    if status:
        query = query.filter_by(status=status)
    return query.order_by(Post.created_at.desc()).limit(min(limit, 200)).all()

@app.post("/posts", response_model=PostOut)
def create_post(payload: PostCreate, user: User = Depends(require_active_license), db: Session = Depends(get_db)):
    if not payload.approval_required and not payload.scheduled_at:
        raise HTTPException(400, "scheduled_at is required for automatic publishing")
    scheduled = payload.scheduled_at
    if scheduled and scheduled.tzinfo is None:
        scheduled = scheduled.replace(tzinfo=timezone.utc)
    if scheduled and scheduled <= datetime.now(timezone.utc):
        raise HTTPException(400, "scheduled_at must be in the future")

    # Deduplicate by client_id if supplied
    if payload.client_id:
        existing = db.query(Post).filter_by(user_id=user.id, client_id=payload.client_id).first()
        if existing:
            return existing

    status = "pending_approval" if payload.approval_required else "scheduled"
    post = Post(
        id=str(uuid4()),
        user_id=user.id,
        client_id=payload.client_id,
        title=payload.title,
        topic=payload.topic,
        body=payload.body,
        status=status,
        approval_required=payload.approval_required,
        scheduled_at=scheduled
    )
    db.add(post)
    db.commit()
    db.refresh(post)
    return post

@app.put("/posts/{post_id}", response_model=PostOut)
def update_post(post_id: str, payload: PostUpdate, user: User = Depends(require_active_license), db: Session = Depends(get_db)):
    post = db.query(Post).filter_by(id=post_id, user_id=user.id).first()
    if not post:
        raise HTTPException(404, "Post not found")
    if post.status == "published":
        raise HTTPException(400, "Cannot edit an already published post")

    if payload.body is not None:
        post.body = payload.body
    if payload.title is not None:
        post.title = payload.title
    if payload.topic is not None:
        post.topic = payload.topic
    if payload.approval_required is not None:
        post.approval_required = payload.approval_required
    if payload.scheduled_at is not None:
        sch = payload.scheduled_at
        if sch and sch.tzinfo is None:
            sch = sch.replace(tzinfo=timezone.utc)
        post.scheduled_at = sch

    post.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(post)
    return post

@app.delete("/posts/{post_id}")
def delete_post(post_id: str, user: User = Depends(require_active_license), db: Session = Depends(get_db)):
    post = db.query(Post).filter_by(id=post_id, user_id=user.id).first()
    if not post:
        raise HTTPException(404, "Post not found")
    db.delete(post)
    db.commit()
    return {"id": post_id, "deleted": True}

@app.post("/posts/{post_id}/approve")
def approve_post(post_id: str, user: User = Depends(require_active_license), db: Session = Depends(get_db)):
    post = db.query(Post).filter_by(id=post_id, user_id=user.id).first()
    if not post:
        raise HTTPException(404, "Post not found")
    if post.status != "pending_approval":
        raise HTTPException(409, f"Post is not awaiting approval (current status: {post.status})")

    post.status = "scheduled"
    if not post.scheduled_at:
        post.scheduled_at = datetime.now(timezone.utc)
    db.commit()
    log_audit(db, user.id, user.email, "POST_APPROVED", "post", post.id, f"Approved for schedule at {post.scheduled_at}")
    return {"id": post.id, "status": post.status, "scheduled_at": post.scheduled_at}

@app.post("/posts/{post_id}/reject")
def reject_post(post_id: str, user: User = Depends(require_active_license), db: Session = Depends(get_db)):
    post = db.query(Post).filter_by(id=post_id, user_id=user.id).first()
    if not post:
        raise HTTPException(404, "Post not found")
    if post.status not in {"pending_approval", "scheduled", "draft"}:
        raise HTTPException(409, f"Cannot reject post in status {post.status}")

    post.status = "rejected"
    db.commit()
    log_audit(db, user.id, user.email, "POST_REJECTED", "post", post.id, "Rejected by user")
    return {"id": post.id, "status": post.status}

@app.post("/posts/sync", response_model=PostSyncResponse)
def sync_posts(payload: PostSyncRequest, user: User = Depends(require_active_license), db: Session = Depends(get_db)):
    now = datetime.now(timezone.utc)
    # Ingest client posts
    for client_item in payload.posts:
        existing = db.query(Post).filter_by(user_id=user.id, client_id=client_item.client_id).first()
        if not existing:
            new_post = Post(
                id=str(uuid4()),
                user_id=user.id,
                client_id=client_item.client_id,
                title=client_item.title,
                topic=client_item.topic,
                body=client_item.body,
                status=client_item.status,
                approval_required=client_item.approval_required,
                scheduled_at=client_item.scheduled_at,
                created_at=client_item.created_at or now,
                updated_at=client_item.updated_at or now
            )
            db.add(new_post)
        else:
            # Server wins if already published/scheduled
            if existing.status not in {"published", "scheduled"}:
                existing.body = client_item.body
                existing.title = client_item.title
                existing.topic = client_item.topic
                existing.status = client_item.status
                existing.approval_required = client_item.approval_required
                existing.scheduled_at = client_item.scheduled_at
                existing.updated_at = now

    db.commit()

    # Query all user posts updated or created
    all_posts = db.query(Post).filter_by(user_id=user.id).order_by(Post.created_at.desc()).limit(200).all()
    return PostSyncResponse(synced_posts=all_posts, server_timestamp=now)

# --- AI Content Generation & Regeneration ---

@app.post("/ai/generate")
@limiter.limit("20/minute")
async def ai_generate(request: Request, payload: AIGenerateRequest, user: User = Depends(require_active_license)):
    content = await generate_cybersecurity_post(payload.topic, custom_api_key=payload.gemini_api_key)
    return {"content": content, "topic": payload.topic, "language": "en"}

@app.post("/ai/regenerate")
@limiter.limit("20/minute")
async def ai_regenerate(request: Request, payload: AIRegenerateRequest, user: User = Depends(require_active_license)):
    content = await regenerate_cybersecurity_post(payload.original_body, payload.topic, payload.instructions, custom_api_key=payload.gemini_api_key)
    return {"content": content, "topic": payload.topic, "language": "en"}

# --- Admin Endpoints ---

@app.get("/admin/overview")
def admin_overview(admin: User = Depends(current_admin), db: Session = Depends(get_db)):
    return {
        "customers": db.query(User).count(),
        "active_licenses": db.query(License).filter_by(active=True).count(),
        "assigned_licenses": db.query(License).filter(License.user_id.isnot(None), License.active.is_(True)).count(),
        "posts": db.query(Post).count(),
        "published_posts": db.query(Post).filter_by(status="published").count(),
        "admin_role": getattr(admin, "admin_role", "staff"),
    }

@app.get("/admin/licenses")
def admin_list_licenses(admin: User = Depends(current_admin), db: Session = Depends(get_db)):
    rows = db.query(License).order_by(License.created_at.desc()).limit(500).all()
    return [{
        "id": x.id,
        "plan": x.plan,
        "billing_cycle": x.billing_cycle,
        "active": x.active,
        "assigned": bool(x.user_id),
        "user_id": x.user_id,
        "expires_at": x.expires_at,
        "created_at": x.created_at,
        "activated_at": x.activated_at,
        "max_devices": x.max_devices
    } for x in rows]

@app.post("/admin/licenses")
def admin_create_license(
    plan: str = "enterprise",
    billing_cycle: str = "monthly",
    days: int | None = None,
    admin: User = Depends(current_admin),
    db: Session = Depends(get_db)
):
    plan_clean = plan.lower().strip()
    valid_plans = {"standard", "pro", "business", "enterprise"}
    if plan_clean not in valid_plans:
        raise HTTPException(400, f"Unsupported plan: {plan} (must be standard, pro, business, or enterprise)")

    duration_days = days
    cycle = billing_cycle.lower().strip()
    if duration_days is not None and duration_days > 0:
        cycle = f"{duration_days}_days"
    elif cycle == "yearly":
        duration_days = 365
    elif cycle == "quarterly":
        duration_days = 90
    elif cycle == "lifetime":
        duration_days = None
    else:
        duration_days = 30
        cycle = "monthly"

    expiry = datetime.now(timezone.utc) + timedelta(days=duration_days) if duration_days else None
    prefix = plan_clean[:3].upper()
    raw_key = f"LP-{prefix}-" + secrets.token_hex(8).upper()

    item = License(
        id=str(uuid4()),
        key_hash=hash_license_key(raw_key),
        plan=plan_clean,
        billing_cycle=cycle,
        active=True,
        expires_at=expiry,
        max_devices=1,
        user_id=None
    )
    db.add(item)
    db.commit()
    db.refresh(item)

    log_audit(db, admin.id, admin.email, "LICENSE_CREATED", "license", item.id, f"Plan: {plan_clean}, Days: {duration_days}")
    return {
        "id": item.id,
        "license_key": raw_key,
        "plan": item.plan,
        "billing_cycle": item.billing_cycle,
        "duration_days": duration_days,
        "expires_at": item.expires_at,
        "issued_by": getattr(admin, "admin_role", "staff"),
        "note": "Copy this key now; it cannot be retrieved again."
    }

@app.post("/admin/licenses/{license_id}/revoke")
def admin_revoke_license(license_id: str, admin: User = Depends(current_super_admin), db: Session = Depends(get_db)):
    item = db.query(License).filter_by(id=license_id).first()
    if not item:
        raise HTTPException(404, "License not found")
    item.active = False
    db.commit()
    log_audit(db, admin.id, admin.email, "LICENSE_REVOKED", "license", item.id, f"Plan was: {item.plan}")
    return {"id": item.id, "active": False}

@app.get("/admin/customers")
def admin_list_customers(admin: User = Depends(current_admin), db: Session = Depends(get_db)):
    users = db.query(User).order_by(User.created_at.desc()).limit(500).all()
    results = []
    now = datetime.now(timezone.utc)
    for u in users:
        lic = db.query(License).filter_by(user_id=u.id, active=True).order_by(License.created_at.desc()).first()
        conn = db.query(LinkedInConnection).filter_by(user_id=u.id).first()
        results.append({
            "id": u.id,
            "email": u.email,
            "created_at": u.created_at,
            "has_active_license": bool(lic and (not lic.expires_at or (lic.expires_at.replace(tzinfo=timezone.utc) if lic.expires_at.tzinfo is None else lic.expires_at) > now)),
            "license_plan": lic.plan if lic else None,
            "license_cycle": lic.billing_cycle if lic else None,
            "linkedin_connected": bool(conn)
        })
    return results

@app.get("/admin/staff")
def admin_list_staff(admin: User = Depends(current_super_admin), db: Session = Depends(get_db)):
    rows = db.query(StaffAdmin).order_by(StaffAdmin.created_at.desc()).all()
    return [{"id": x.id, "email": x.email, "active": x.active, "created_at": x.created_at} for x in rows]

@app.post("/admin/staff")
def admin_add_staff(payload: StaffCreate, admin: User = Depends(current_super_admin), db: Session = Depends(get_db)):
    email = payload.email.strip().lower()
    if email in _super_admin_emails():
        raise HTTPException(409, "This email is already a Super Admin")
    existing = db.query(StaffAdmin).filter_by(email=email).first()
    if existing:
        existing.active = True
        db.commit()
        log_audit(db, admin.id, admin.email, "STAFF_REACTIVATED", "staff", existing.id, email)
        return {"id": existing.id, "email": existing.email, "active": True}
    item = StaffAdmin(id=str(uuid4()), email=email, active=True)
    db.add(item)
    db.commit()
    db.refresh(item)
    log_audit(db, admin.id, admin.email, "STAFF_ADDED", "staff", item.id, email)
    return {"id": item.id, "email": item.email, "active": item.active}

@app.post("/admin/staff/{staff_id}/revoke")
def admin_revoke_staff(staff_id: str, admin: User = Depends(current_super_admin), db: Session = Depends(get_db)):
    item = db.query(StaffAdmin).filter_by(id=staff_id).first()
    if not item:
        raise HTTPException(404, "Staff account not found")
    item.active = False
    db.commit()
    log_audit(db, admin.id, admin.email, "STAFF_REVOKED", "staff", item.id, item.email)
    return {"id": item.id, "active": False}

@app.get("/admin/audit-logs", response_model=list[AuditLogOut])
def admin_get_audit_logs(limit: int = 100, admin: User = Depends(current_super_admin), db: Session = Depends(get_db)):
    return db.query(AuditLog).order_by(AuditLog.created_at.desc()).limit(min(limit, 200)).all()
