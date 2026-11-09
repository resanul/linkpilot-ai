import pytest
from unittest.mock import patch, AsyncMock
from datetime import datetime, timezone, timedelta
from uuid import uuid4
from app.models import Post, User, License, LinkedInConnection
from app.scheduler import scheduled_publish_worker
from app.security import encrypt_secret

@pytest.mark.asyncio
async def test_scheduler_worker_success(db):
    # Setup user with valid license and valid LinkedIn connection
    user = User(id=str(uuid4()), google_sub="sub-worker-test", email="worker@example.com")
    db.add(user)
    db.commit()

    lic = License(
        id=str(uuid4()),
        user_id=user.id,
        key_hash="hash-123",
        plan="pro",
        billing_cycle="yearly",
        active=True,
        expires_at=datetime.now(timezone.utc) + timedelta(days=300)
    )
    conn = LinkedInConnection(
        id=str(uuid4()),
        user_id=user.id,
        person_urn="urn:li:person:worker123",
        profile_name="Worker User",
        access_token_encrypted=encrypt_secret("test-access-token"),
        expires_at=datetime.now(timezone.utc) + timedelta(days=60)
    )
    post = Post(
        id=str(uuid4()),
        user_id=user.id,
        body="Automated cybersecurity insight for scheduled publication. #InfoSec #CyberSecurity",
        status="scheduled",
        approval_required=False,
        scheduled_at=datetime.now(timezone.utc) - timedelta(minutes=5)
    )
    db.add_all([lic, conn, post])
    db.commit()

    with patch("app.scheduler.publish_text_post", new_callable=AsyncMock) as mock_pub:
        mock_pub.return_value = "urn:li:share:99887766"
        await scheduled_publish_worker()

        # Refresh post from db
        db.refresh(post)
        assert post.status == "published"
        assert post.linkedin_post_id == "urn:li:share:99887766"
        assert post.published_at is not None
        assert post.error_message is None

@pytest.mark.asyncio
async def test_scheduler_prevents_duplicate_publishing(db):
    # If post is already published, worker must ignore it
    user = db.query(User).filter_by(google_sub="sub-worker-test").first()
    post = Post(
        id=str(uuid4()),
        user_id=user.id,
        body="Already published post",
        status="published",
        scheduled_at=datetime.now(timezone.utc) - timedelta(hours=1),
        linkedin_post_id="urn:li:share:already"
    )
    db.add(post)
    db.commit()

    with patch("app.scheduler.publish_text_post", new_callable=AsyncMock) as mock_pub:
        await scheduled_publish_worker()
        mock_pub.assert_not_called()

@pytest.mark.asyncio
async def test_scheduler_handles_expired_license(db):
    user = User(id=str(uuid4()), google_sub="sub-expired-lic", email="expiredlic@example.com")
    db.add(user)
    db.commit()

    # Expired license
    lic = License(
        id=str(uuid4()),
        user_id=user.id,
        key_hash="hash-exp",
        plan="pro",
        billing_cycle="monthly",
        active=True,
        expires_at=datetime.now(timezone.utc) - timedelta(days=1)
    )
    conn = LinkedInConnection(
        id=str(uuid4()),
        user_id=user.id,
        person_urn="urn:li:person:exp123",
        access_token_encrypted=encrypt_secret("test-token"),
        expires_at=datetime.now(timezone.utc) + timedelta(days=10)
    )
    post = Post(
        id=str(uuid4()),
        user_id=user.id,
        body="Post with expired license",
        status="scheduled",
        scheduled_at=datetime.now(timezone.utc) - timedelta(minutes=2)
    )
    db.add_all([lic, conn, post])
    db.commit()

    await scheduled_publish_worker()
    db.refresh(post)
    assert post.status == "failed"
    assert "License inactive or expired" in (post.error_message or "")
