# Antigravity handoff — LinkPilot AI Phase 4

You are continuing an existing Flutter + FastAPI project. Do not replace the architecture or remove existing screens. Work in small commits and report every command, test result, changed file, and known limitation.

## Product requirements
- Commercial multi-customer Android app; each customer connects exactly one LinkedIn account.
- Google Sign-In is app authentication. LinkedIn OAuth is a separate consent flow. Never ask for LinkedIn passwords or cookies.
- License activation is mandatory before customer features. Plans: Standard, Pro, Business. Billing: Monthly, Yearly, Lifetime. Manual issue by mobile admin.
- Admin roles: Super Admin and Staff. Super Admin can add/revoke staff and revoke licenses. Staff can view customers/licenses and issue licenses.
- Mixed publishing: approval queue plus explicitly scheduled automatic publishing. Default content is English cybersecurity posts. Bangladesh timezone is Asia/Dhaka.
- Keep a local phone history and synchronize it with backend history. Do not claim sync works until implemented and tested.

## Phase 1 — inspect before editing
1. Read `README.md`, `backend/app`, and `mobile/lib/main.dart`.
2. Check Flutter/Dart/Python versions and installed Android SDK.
3. Create a git branch `antigravity/phase4-integration` and commit the untouched baseline.
4. Do not overwrite working source with generated boilerplate.

## Phase 2 — backend
1. Create a virtual environment and install `backend/requirements.txt`.
2. Run Python syntax checks and start FastAPI. Verify `/health`.
3. Review `backend/migrations/phase4_sqlite.sql` or `phase4_postgresql.sql`. Back up any existing DB before applying. Do not blindly run both. For fresh DB, SQLAlchemy models create tables; still verify schema.
4. Validate Google ID-token verification using a real configured OAuth client. Never trust email/user ID sent in JSON.
5. Verify license activation, status and enforcement. Test expired, revoked, already-assigned and valid keys.
6. Verify admin role boundaries with separate Super Admin, Staff, and ordinary user identities.
7. Verify OAuth state is single-use, user-bound, expires in 10 minutes, and callback stores only encrypted access tokens. Test invalid/expired/replayed state.
8. Confirm LinkedIn app has approved `openid`, `profile`, `w_member_social` access and the configured redirect URI exactly matches. API access is controlled by LinkedIn; do not bypass approval.
9. Verify the LinkedIn `/v2/userinfo` profile identity and `/rest/posts` payload with a developer/test account only. Confirm current API version from official LinkedIn docs before release.
10. Test Gemini generation with server-side API key. Never put provider keys in Flutter.
11. Test scheduler in a test mode with short intervals; do not wait until 20:00. Confirm failed jobs are visible and never silently reported as published.
12. Add rate limiting, audit logging, structured error handling, retry/backoff with idempotency, and production DB migrations before launch.

## Phase 3 — Flutter app
1. Wire Google Sign-In; send Google ID token as `Authorization: Bearer <id_token>` to backend.
2. Add secure token storage using `flutter_secure_storage`; do not store secrets in source or shared preferences.
3. Add API client with configurable base URL via `--dart-define=API_BASE_URL=...`.
4. Wire license activation/status, LinkedIn connect via external browser, post create/list/approve, AI generation, admin overview/licenses/customers/staff endpoints.
5. Keep Admin/User mode as a presentation switch only. Always rely on backend authorization; hide admin screens if API denies access.
6. Implement local SQLite history plus authenticated cloud sync with conflict handling and account isolation. Add logout and account-switch cleanup.
7. Show clear states for expired license, LinkedIn disconnected/expired, network failure, pending approval, scheduled, published and failed.
8. Ensure automatic publishing requires explicit opt-in and an explicit scheduled time. Ask confirmation before first enabling auto-publish.

## Phase 4 — build and test
Run and report:
- `flutter doctor -v`
- `flutter pub get`
- `flutter analyze`
- `flutter test`
- `flutter build apk --release --dart-define=API_BASE_URL=https://YOUR_API_HOST`
- backend unit/API tests (include auth, tenant isolation, license gates, role gates, OAuth state replay, encryption, AI error handling, publish failure)
- install APK on an Android device/emulator and test login, activation, LinkedIn connect, draft, approval, scheduled publish, history, admin flows, logout.

Do not put production credentials into the APK, repository, screenshots, logs, or build artifacts. Use test accounts and a staging backend. Do not call the project production-ready until all acceptance tests pass and LinkedIn app permissions are approved.

## Deliverables
- Updated source code and a source ZIP.
- Release APK and SHA-256 checksum (only if build succeeds).
- Test report with pass/fail, device/OS, backend environment, API permission status, and unresolved issues.
- Deployment/runbook and `.env.example` only; never include `.env` or real secrets.
