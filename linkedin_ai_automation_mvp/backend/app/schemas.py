from pydantic import BaseModel, Field
from datetime import datetime

class LicenseActivate(BaseModel):
    license_key: str = Field(min_length=8, max_length=128)

class PostCreate(BaseModel):
    body: str = Field(min_length=1, max_length=3000)
    approval_required: bool = True
    scheduled_at: datetime | None = None

class PostOut(BaseModel):
    id: str
    body: str
    status: str
    approval_required: bool
    scheduled_at: datetime | None
    created_at: datetime
    model_config = {"from_attributes": True}


class StaffCreate(BaseModel):
    email: str = Field(min_length=5, max_length=320)
