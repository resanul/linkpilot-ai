# LinkedIn AI Automation — MVP Starter

A Flutter Android app + FastAPI backend starter for a license-gated, single-LinkedIn-account automation product.

## Included
- Flutter dashboard UI with mixed publishing mode (approval queue + auto-publish setting)
- Local SQLite post history model
- FastAPI backend skeleton for license activation, Google ID-token verification hook, LinkedIn OAuth start/callback placeholders, post drafts/history sync
- Scheduler scaffold (Asia/Dhaka, 20:00) with a safe no-op publisher until LinkedIn OAuth/API is configured
- `.env.example`, Dockerfile and API notes

## Important status
This is a **starter implementation**, not a production-connected app. LinkedIn OAuth credentials, Google OAuth audience, database, HTTPS deployment, AI provider key, and LinkedIn API product approval/configuration are not supplied. The LinkedIn publish adapter deliberately fails closed until configured. Do not add real tokens to source control.

## Architecture
- Android app: Flutter
- API: FastAPI
- Cloud DB: PostgreSQL (SQLAlchemy)
- Local history: SQLite (`sqflite`)
- Scheduler: APScheduler
- AI: provider adapter placeholder; configure an API provider server-side
- LinkedIn: official OAuth 2.0 member authorization and Posts API only

## Run backend locally
```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
uvicorn app.main:app --reload
```
The API health endpoint is `GET /health`.

## Issue a license (admin-side, local/dev only)
```bash
cd backend
python scripts/create_license.py YOUR-ONE-TIME-LICENSE-KEY
```
This stores only a SHA-256 hash. For production, replace this with an authenticated admin console, stronger keyed hashing, expiry/plan/device limits, audit logs and payment-provider webhook verification.

## Run Flutter app
Install Flutter and Android Studio, then:
```bash
cd mobile
flutter create .
flutter pub get
flutter run
```
The current mobile app is a UI + local-history scaffold. Configure `API_BASE_URL` and Google Sign-In/OAuth before connecting real accounts.

## Required setup before live publishing
1. Create Google OAuth credentials and set `GOOGLE_CLIENT_ID` (backend must verify ID tokens; do not trust a client-supplied email).
2. Configure LinkedIn app OAuth redirect URI to `https://YOUR_API_HOST/linkedin/callback`.
3. Request/enable LinkedIn "Share on LinkedIn" and use the minimum required permission (`w_member_social`). LinkedIn access and API behavior are controlled by LinkedIn.
4. Add `LINKEDIN_CLIENT_ID`, `LINKEDIN_CLIENT_SECRET`, `LINKEDIN_REDIRECT_URI`, and a supported API version to a secret manager.
5. Implement token encryption with a managed KMS/secret manager before storing refresh/access tokens.
6. Set `DATABASE_URL`, `AI_PROVIDER`, and `AI_API_KEY` in server environment.
7. Deploy backend and worker with HTTPS; configure backups, rate limits, audit logging and tenant isolation.
8. Test with a developer/test account before enabling automatic publishing.

## Mixed publishing behavior
- `approval_required=true`: generated post remains pending until user approves.
- `approval_required=false`: generated post is eligible for scheduled publishing.
- A user-level setting controls the default; each post can override it.
- Never auto-comment on arbitrary feed posts. Comment workflows must be user-selected and permitted by the LinkedIn API product/scopes.

## Privacy and security
- Google login is for app identity; LinkedIn OAuth separately authorizes publishing.
- Never collect LinkedIn passwords.
- Keep client secrets and provider keys on the backend only.
- Encrypt OAuth tokens at rest; use HTTPS; enforce ownership checks on every record.
- Local SQLite is a convenience copy, not the only backup. Cloud history remains the source of truth.


## Commercial mobile-admin phase (scaffold)
- Added mobile User/Admin mode screens.
- Added admin overview, license manager and customer screens.
- Added backend admin overview, license list/create/revoke endpoints.
- Admin API authorization uses a server-side `ADMIN_EMAILS` allowlist after Google ID-token verification.
- Generated license plaintext is returned once; only its hash is stored.

Production requirements: wire mobile Google Sign-In and API calls, implement customer list/pagination, add database migrations (existing tables are not altered by `create_all()`), HTTPS, rate limits, audit logs, encrypted LinkedIn token storage, payment provider webhooks and subscription renewal. The Admin/User mode toggle in this starter is a visual prototype, not an authorization boundary. The backend allowlist is the actual authorization check.


## Commercial licensing decisions
- Manual license issuance from the mobile Admin Mode only.
- Billing cycles: monthly (30 days), yearly (365 days), lifetime (no expiry).
- Plan tiers: standard, pro, business.
- Super Admin emails are configured through server-side `ADMIN_EMAILS`.
- Super Admin can add/revoke staff; staff can view customers/licenses and issue licenses; staff cannot revoke licenses or manage staff.
- No payment gateway or automatic license issuance is enabled.

## Database migration warning
The commercial schema adds `licenses.billing_cycle` and the `staff_admins` table. For a fresh development database, the app's `create_all()` creates them. For an existing database, create and apply a proper Alembic migration before deployment; `create_all()` does not alter existing tables.


## Phase 4 — integration foundation (November 2026)
This phase adds: HMAC-based license-key hashing (requires `LICENSE_SIGNING_SECRET` outside dev), verified Google email claim checks, active-license gates on customer endpoints, expiring single-use LinkedIn OAuth state bound to the initiating user, encrypted LinkedIn access-token storage using Fernet, LinkedIn profile lookup, Gemini text generation adapter, and a scheduled publishing worker. It also adds migration SQL and `ANTIGRAVITY_TASK.md`.

**Not production-ready:** Flutter Google Sign-In/API integration, cloud/local history sync, admin screen wiring, robust audit/rate-limit controls, token refresh/reconnect UX, production migration orchestration, full automated test coverage, and an Android release build remain to be completed and verified by Antigravity. LinkedIn API permissions and product approval are external prerequisites. The scheduler is a single-process MVP worker; use a dedicated worker/queue with distributed locking before multi-instance production deployment.

### Generate secrets (backend only)
```bash
python -c "import secrets; print(secrets.token_urlsafe(48))"
python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
```
Never commit `.env`, API keys, OAuth secrets, or real tokens.
