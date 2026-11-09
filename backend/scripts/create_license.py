"""LinkPilot AI - License Minter CLI
Generate cryptographically hashed license keys with custom validity days for customers.
"""

import argparse
import secrets
from datetime import datetime, timedelta, timezone
from uuid import uuid4
import sys
import os

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.db import Base, engine, SessionLocal
from app.models import License
from app.security import hash_license_key

def main():
    parser = argparse.ArgumentParser(description="Create a LinkPilot license key with custom validity.")
    parser.add_argument("--key", default=None, help="Optional custom key (auto-generated if omitted)")
    parser.add_argument("--plan", choices=["standard", "pro", "business", "enterprise"], default="enterprise")
    parser.add_argument("--days", type=int, default=30, help="Validity duration in days (e.g. 30, 90, 365; 0 for lifetime)")
    args = parser.parse_args()

    Base.metadata.create_all(bind=engine)

    duration = args.days if args.days > 0 else None
    cycle = f"{args.days}_days" if duration else "lifetime"
    expiry = datetime.now(timezone.utc) + timedelta(days=duration) if duration else None

    raw_key = args.key
    if not raw_key:
        prefix = args.plan[:3].upper()
        raw_key = f"LP-{prefix}-" + secrets.token_hex(8).upper()

    db = SessionLocal()
    try:
        item = License(
            id=str(uuid4()),
            key_hash=hash_license_key(raw_key),
            plan=args.plan,
            billing_cycle=cycle,
            expires_at=expiry,
            active=True,
            user_id=None
        )
        db.add(item)
        db.commit()

        print("=" * 60)
        print("🎉 License Key Created Successfully!")
        print("=" * 60)
        print(f"🔑 License Key:  {raw_key}")
        print(f"📦 Plan:         {args.plan.upper()}")
        print(f"⏳ Duration:     {f'{duration} Days' if duration else 'Lifetime'}")
        print(f"📅 Expires At:   {expiry.strftime('%Y-%m-%d %H:%M:%S UTC') if expiry else 'Never (Lifetime)'}")
        print("=" * 60)
        print("Send this key to your customer. They will enter it in their LinkPilot mobile app.")
    finally:
        db.close()

if __name__ == "__main__":
    main()
