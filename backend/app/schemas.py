from pydantic import BaseModel, Field
from datetime import datetime

class LicenseActivate(BaseModel):
    license_key: str = Field(min_length=8, max_length=128)

class PostCreate(BaseModel):
    body: str = Field(min_length=1, max_length=3000)
    title: str | None = Field(default=None, max_length=255)
    topic: str | None = Field(default=None, max_length=255)
    approval_required: bool = True
    scheduled_at: datetime | None = None
    client_id: str | None = Field(default=None, max_length=64)

class PostUpdate(BaseModel):
    body: str | None = Field(default=None, min_length=1, max_length=3000)
    title: str | None = Field(default=None, max_length=255)
    topic: str | None = Field(default=None, max_length=255)
    approval_required: bool | None = None
    scheduled_at: datetime | None = None

class PostOut(BaseModel):
    id: str
    client_id: str | None = None
    title: str | None = None
    topic: str | None = None
    body: str
    status: str
    approval_required: bool
    scheduled_at: datetime | None = None
    published_at: datetime | None = None
    linkedin_post_id: str | None = None
    error_message: str | None = None
    retry_count: int = 0
    created_at: datetime
    updated_at: datetime | None = None
    model_config = {"from_attributes": True}

class PostSyncItem(BaseModel):
    client_id: str
    title: str | None = None
    topic: str | None = None
    body: str
    status: str = "draft"
    approval_required: bool = True
    scheduled_at: datetime | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None

class PostSyncRequest(BaseModel):
    posts: list[PostSyncItem] = Field(default_factory=list)
    last_sync_timestamp: datetime | None = None

class PostSyncResponse(BaseModel):
    synced_posts: list[PostOut]
    server_timestamp: datetime

class StaffCreate(BaseModel):
    email: str = Field(min_length=5, max_length=320)

class AIGenerateRequest(BaseModel):
    topic: str = Field(default="cybersecurity", max_length=200)
    gemini_api_key: str | None = Field(default=None, max_length=255)

class AIRegenerateRequest(BaseModel):
    original_body: str = Field(min_length=1, max_length=3000)
    topic: str = Field(default="cybersecurity", max_length=200)
    instructions: str | None = Field(default=None, max_length=500)
    gemini_api_key: str | None = Field(default=None, max_length=255)

class LinkedInManualConnect(BaseModel):
    access_token: str = Field(min_length=10)

class UserProfileOut(BaseModel):
    id: str
    email: str
    role: str
    admin_role: str | None = None
    has_active_license: bool
    license_plan: str | None = None
    license_cycle: str | None = None
    license_expires_at: datetime | None = None
    linkedin_connected: bool
    linkedin_profile_name: str | None = None
    created_at: datetime

class AuditLogOut(BaseModel):
    id: str
    actor_id: str | None
    actor_email: str | None
    action: str
    target_type: str | None
    target_id: str | None
    details: str | None
    created_at: datetime
    model_config = {"from_attributes": True}
