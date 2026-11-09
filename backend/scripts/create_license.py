import argparse
from datetime import datetime, timedelta, timezone
from uuid import uuid4
from app.db import Base, engine, SessionLocal
from app.models import License
from app.security import hash_license_key

parser = argparse.ArgumentParser(description="Create a one-time LinkPilot license key (local/dev only).")
parser.add_argument("license_key")
parser.add_argument("--plan", choices=["standard", "pro", "business"], default="standard")
parser.add_argument("--cycle", choices=["monthly", "yearly", "lifetime"], default="monthly")
args = parser.parse_args()
Base.metadata.create_all(bind=engine)
days = {"monthly": 30, "yearly": 365, "lifetime": None}[args.cycle]
expiry = datetime.now(timezone.utc) + timedelta(days=days) if days else None
db = SessionLocal()
try:
    item = License(id=str(uuid4()), key_hash=hash_license_key(args.license_key),
                   plan=args.plan, billing_cycle=args.cycle, expires_at=expiry, active=True, user_id=None)
    db.add(item)
    db.commit()
    print(f"Created license record: {item.id}")
    print(f"Plan: {args.plan}; cycle: {args.cycle}; expires: {expiry or 'never'}")
    print("Store and deliver the plaintext key securely; it cannot be retrieved from the database.")
finally:
    db.close()
