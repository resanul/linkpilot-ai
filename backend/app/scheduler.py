import logging
from datetime import datetime, timezone
from zoneinfo import ZoneInfo
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from sqlalchemy import and_
from .db import SessionLocal
from .models import Post, License, LinkedInConnection, AuditLog
from .security import decrypt_secret
from .linkedin import publish_text_post
from uuid import uuid4

logger = logging.getLogger("linkpilot.scheduler")

scheduler = AsyncIOScheduler(timezone=ZoneInfo("Asia/Dhaka"))

MAX_PUBLISH_RETRIES = 3

async def scheduled_publish_worker():
    """
    Background worker that runs every minute and at 20:00 Asia/Dhaka.
    Processes all posts in 'scheduled' status where scheduled_at <= now.
    Enforces active license entitlement, valid LinkedIn connection, retry bounds,
    and updates database records with audit trails.
    """
    db = SessionLocal()
    try:
        now = datetime.now(timezone.utc)
        due_posts = (
            db.query(Post)
            .filter(
                and_(
                    Post.status == "scheduled",
                    Post.scheduled_at.isnot(None),
                    Post.scheduled_at <= now,
                    Post.retry_count < MAX_PUBLISH_RETRIES
                )
            )
            .order_by(Post.scheduled_at.asc())
            .limit(25)
            .all()
        )

        for post in due_posts:
            # 1. Verify user still holds an active, non-expired license
            license_rows = (
                db.query(License)
                .filter(License.user_id == post.user_id, License.active.is_(True))
                .all()
            )
            has_valid_license = False
            for lic in license_rows:
                expiry = lic.expires_at
                if expiry and expiry.tzinfo is None:
                    expiry = expiry.replace(tzinfo=timezone.utc)
                if not expiry or expiry > now:
                    has_valid_license = True
                    break

            if not has_valid_license:
                post.status = "failed"
                post.error_message = "License inactive or expired at execution time"
                continue

            # 2. Verify active LinkedIn connection
            connection = db.query(LinkedInConnection).filter_by(user_id=post.user_id).first()
            if not connection:
                post.status = "failed"
                post.error_message = "No LinkedIn account connected"
                continue

            # 3. Verify LinkedIn access token expiry
            token_expiry = connection.expires_at
            if token_expiry and token_expiry.tzinfo is None:
                token_expiry = token_expiry.replace(tzinfo=timezone.utc)
            if token_expiry and token_expiry <= now:
                post.status = "failed"
                post.error_message = "LinkedIn OAuth token has expired. Re-authentication required"
                continue

            # 4. Attempt post publishing with retry tracking
            try:
                token = decrypt_secret(connection.access_token_encrypted)
                post_urn = await publish_text_post(token, connection.person_urn, post.body)
                post.linkedin_post_id = post_urn
                post.status = "published"
                post.published_at = datetime.now(timezone.utc)
                post.error_message = None

                # Record audit log
                db.add(AuditLog(
                    id=str(uuid4()),
                    actor_id=post.user_id,
                    action="POST_PUBLISHED",
                    target_type="post",
                    target_id=post.id,
                    details=f"Published to LinkedIn ({post_urn})"
                ))
            except Exception as exc:
                post.retry_count += 1
                error_str = str(exc)
                logger.error(f"Error publishing post {post.id} (attempt {post.retry_count}): {error_str}")
                post.error_message = f"Publishing error (attempt {post.retry_count}/{MAX_PUBLISH_RETRIES}): {error_str}"
                if post.retry_count >= MAX_PUBLISH_RETRIES:
                    post.status = "failed"

        db.commit()
    except Exception as exc:
        db.rollback()
        logger.error(f"Error in scheduled_publish_worker: {exc}")
    finally:
        db.close()

def start_scheduler():
    if not scheduler.running:
        scheduler.add_job(
            scheduled_publish_worker,
            "cron",
            hour=20,
            minute=0,
            timezone=ZoneInfo("Asia/Dhaka"),
            id="daily-publish",
            replace_existing=True,
            max_instances=1
        )
        scheduler.add_job(
            scheduled_publish_worker,
            "interval",
            minutes=1,
            id="due-posts",
            replace_existing=True,
            max_instances=1
        )
        scheduler.start()
        logger.info("Scheduler started with Dhaka daily 20:00 cron and 1-minute interval worker.")
