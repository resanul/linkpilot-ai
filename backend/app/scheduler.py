from datetime import datetime, timezone
from zoneinfo import ZoneInfo
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from sqlalchemy import and_
from .db import SessionLocal
from .models import Post, License, LinkedInConnection
from .security import decrypt_secret
from .linkedin import publish_text_post

scheduler = AsyncIOScheduler(timezone=ZoneInfo("Asia/Dhaka"))

async def scheduled_publish_worker():
    # Fetch due work; each post is revalidated before attempting publish.
    db = SessionLocal()
    try:
        now = datetime.now(timezone.utc)
        due = db.query(Post).filter(and_(Post.status == "scheduled", Post.approval_required.is_(False), Post.scheduled_at.isnot(None), Post.scheduled_at <= now)).limit(25).all()
        for post in due:
            license_row = db.query(License).filter(License.user_id == post.user_id, License.active.is_(True)).first()
            connection = db.query(LinkedInConnection).filter_by(user_id=post.user_id).first()
            expiry = license_row.expires_at if license_row else None
            if expiry and expiry.tzinfo is None:
                expiry = expiry.replace(tzinfo=timezone.utc)
            if not license_row or (expiry and expiry <= now) or not connection:
                post.status = "failed"
                continue
            token_expiry = connection.expires_at
            if token_expiry and token_expiry.tzinfo is None:
                token_expiry = token_expiry.replace(tzinfo=timezone.utc)
            if token_expiry and token_expiry <= now:
                post.status = "failed"
                continue
            try:
                token = decrypt_secret(connection.access_token_encrypted)
                post.linkedin_post_id = await publish_text_post(token, connection.person_urn, post.body)
                post.status = "published"
            except Exception:
                post.status = "failed"
        db.commit()
    finally:
        db.close()

def start_scheduler():
    if not scheduler.running:
        scheduler.add_job(scheduled_publish_worker, "cron", hour=20, minute=0, timezone=ZoneInfo("Asia/Dhaka"), id="daily-publish", replace_existing=True, max_instances=1)
        scheduler.add_job(scheduled_publish_worker, "interval", minutes=1, id="due-posts", replace_existing=True, max_instances=1)
        scheduler.start()
