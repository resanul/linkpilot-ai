# 🧠 LinkPilot AI — Project Memory, Task Ledger & Problem-Solution Changelog

> **Living Document & Operational Memory**: This file serves as the definitive, single-source-of-truth log for all engineering work, architectural milestones, problem-solution records, and future roadmaps for **LinkPilot AI** (`linkpilot-ai`). Every new task executed must be appended to this document to preserve institutional memory.

---

## 📌 Table of Contents
1. [System Architecture Overview](#system-architecture-overview)
2. [Historical Task & Feature Ledger](#historical-task--feature-ledger)
3. [Problem & Solution Incident Ledger](#problem--solution-incident-ledger)
4. [Current System State & Capabilities Inventory](#current-system-state--capabilities-inventory)
5. [Future Roadmap & Potential Enhancements](#future-roadmap--potential-enhancements)
6. [Continuous Memory Protocol](#continuous-memory-protocol)

---

## 🏗️ System Architecture Overview

LinkPilot AI is an autonomous B2B SaaS platform that builds cybersecurity thought leadership on LinkedIn. It is architected around 4 core principles:

1. **Centralized Platform AI**: The backend handles Google Gemini AI post generation centrally. End users never supply, configure, or pay for AI API keys.
2. **Fair Commercial Licensing**: Subscriptions are issued in clean formats (`LP-ENT-XXXX-XXXX`) for flexible durations (30, 60, 90, 180, 365 days, or Lifetime). Expiry countdown begins strictly upon **first activation** (`now + duration_days`).
3. **Decoupled User vs. Admin Experiences**:
   - **End Users**: Get a clean client workspace (LinkedIn connection, post creator, scheduler, approval queue, timeline history). No administrative buttons, PIN dialogs, or backend toggles exist in user view.
   - **Administrators**: Access an isolated Admin Console secured behind a Master Admin PIN (`889900`) to mint licenses, inspect customers, monitor device limits, and view immutable audit logs.
4. **Autonomous Serverless Publishing**: A standalone GitHub Actions workflow (`.github/workflows/daily_post.yml`) automatically executes daily at 20:00 Asia/Dhaka (14:00 UTC) with SQLite history persistence and duplicate topic avoidance.

---

## 📜 Historical Task & Feature Ledger

### [TASK-001] GitHub Actions Daily Automation Setup
- **Objective**: Establish zero-cost, persistent daily cybersecurity post publishing to LinkedIn.
- **Components Built**:
  - `automation/generate_post.py`: AI generator cycling through 12 cybersecurity domains with hashtag optimization.
  - `automation/publish_linkedin.py`: LinkedIn UGC Posts REST API client.
  - `.github/workflows/daily_post.yml`: Cron schedule at `14:00 UTC` (`20:00 Asia/Dhaka`) with dry-run support.
  - SQLite database `data/posts.db` committing publishing history back to Git.

### [TASK-002] FastAPI Commercial SaaS Backend
- **Objective**: Build a multi-tenant backend with licensing, role-based access control, and synchronization.
- **Components Built**:
  - FastAPI application with SQLAlchemy ORM and Alembic migrations.
  - HMAC-SHA256 license verification engine (`backend/app/security.py`).
  - Google ID token verification and LinkedIn OAuth connection manager.
  - Scheduled publication background daemon with APScheduler.
  - Pytest automated test suite covering 20 test cases.

### [TASK-003] Flutter Android Application Foundation
- **Objective**: Develop a modern Android client for customers and administrators.
- **Components Built**:
  - Secure offline-first SQLite database (`local_db_service.dart`) with encrypted token storage.
  - Post Editor, AI Generator with 12 domain selector, Approval Queue, and Scheduler screens.
  - Bi-directional sync service with conflict resolution.

### [TASK-004] Centralized Platform AI Engine
- **Objective**: Remove the requirement for end users to provide their own Google Gemini API keys.
- **Components Built**:
  - Shifted Gemini generation entirely to backend server.
  - Configured customer app to use central AI endpoint seamlessly.

### [TASK-005] Commercial License Duration Engine
- **Objective**: Implement customizable license durations (30d, 60d, 90d, 365d, lifetime) with live remaining day tracking.
- **Components Built**:
  - `backend/app/main.py`: Updated `admin_create_license` to accept custom `days` and set `billing_cycle`.
  - Updated `activate_license` to calculate `expires_at = now + duration_days` on first activation.
  - Added `days_remaining` to `UserProfileOut` schema and `UserModel` in Flutter.
  - Created dynamic badge in dashboard banner: `${daysRemaining} DAYS REMAINING`.
  - Upgraded CLI minting script: `backend/scripts/create_license.py --plan enterprise --days 30`.

### [TASK-006] Master Admin PIN Security & Remote Setup
- **Objective**: Secure admin portal behind Master PIN `889900` and link to GitHub remote `git@github.com:resanul/linkpilot-ai.git`.
- **Components Built**:
  - Configured ED25519 SSH deploy key on developer machine.
  - Pushed codebase to GitHub repository `resanul/linkpilot-ai`.
  - Added `X-Admin-Pin: 889900` validation in backend dependency injection.

### [TASK-007] Role-Based Login Screen (User Login vs. Admin Login)
- **Objective**: Add dedicated login options on the Login Screen so admins log in as Admin and users log in as User.
- **Components Built**:
  - Redesigned `mobile/lib/screens/login_screen.dart` with dual-mode selector:
    - **[User Login]**: Google Account / Email / Project Mode -> License Activation -> Customer Dashboard.
    - **[Admin Login]**: Master Admin PIN (`889900`) -> Dedicated Admin Console.
  - Allowed direct email string authentication in dev mode (`backend/app/security.py`).

### [TASK-008] Splash Screen Routing Fix
- **Objective**: Fix bug where `SplashScreen` was automatically bypassing the login page and jumping straight to the dashboard.
- **Components Built**:
  - Updated `mobile/lib/screens/splash_screen.dart` to navigate directly to `LoginScreen` on startup.

### [TASK-009] Decoupling User Dashboard & Admin Console
- **Objective**: Completely eliminate admin controls, PIN dialogs, and admin sub-pages from the user dashboard.
- **Components Built**:
  - Stripped all `_adminMode`, `_promptAdminPin`, and `adminPages` from `mobile/lib/screens/dashboard_screen.dart`.
  - Created standalone `mobile/lib/screens/admin/admin_portal_screen.dart` with dedicated AppBar, Overview, Licenses, Customers, and Audit Logs tabs, and an explicit "Exit Admin" button.

### [TASK-010] Google Account Onboarding & Admin Approval Gate
- **Objective**: Prevent unapproved users from immediately gaining access upon logging in with Google. All new accounts enter a `pending_approval` state (`is_approved = False`). Admins review new users in the Admin Console and approve or reject them. Until approved, the user sees an "Approval Pending" screen and cannot activate licenses or access the workspace.
- **Components Built**:
  - `backend/app/models.py`: Added `is_approved: Mapped[bool] = mapped_column(Boolean, default=False)` and `approved_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)` to `User`.
  - `backend/app/schemas.py`: Added `is_approved` and `approved_at` to `UserProfileOut`.
  - `backend/app/main.py`:
    - Added `ensure_db_migrations()` during startup lifespan to execute automatic `ALTER TABLE users ADD COLUMN is_approved ...` on SQLite.
    - Updated `resolve_actor`: Automatically approves admins (`resanul@gmail.com`, `admin@linkpilot.ai`, `settings.admin_emails`, or `test` env). New users default to `is_approved = False`.
    - Updated `require_active_license` and `activate_license`: Block unapproved users with `HTTP 403 Account is awaiting administrator approval`.
    - Added endpoints:
      - `POST /admin/customers/{user_id}/approve`: Approves user and logs audit `CUSTOMER_APPROVED`.
      - `POST /admin/customers/{user_id}/reject`: Suspends user and logs audit `CUSTOMER_REJECTED`.
  - `mobile/lib/models/user_model.dart`: Added `isApproved` and `approvedAt` fields and updated factory constructors.
  - `mobile/lib/services/api_client.dart`: Added `approveAdminCustomer(userId)` and `rejectAdminCustomer(userId)`.
  - `mobile/lib/screens/pending_approval_screen.dart`: Created dedicated waiting screen with live status polling, account email, review badge, and sign-out options.
  - `mobile/lib/screens/login_screen.dart`: Intercepts unapproved users and routes them to `PendingApprovalScreen`.
  - `mobile/lib/screens/admin/admin_customers_screen.dart`: Added filter pills (`All`, `Pending Approval (N)`, `Approved`), pending approval badges, and direct **[ ✅ Approve Access ]** and **[ ❌ Reject ]** buttons.
  - `mobile/test/widget_test.dart`: Added widget test for `PendingApprovalScreen`.

### [TASK-011] GitHub Cloud Serverless Backend & Google Sign-In Streamlining
- **Objective**: Eliminate confusing developer "tokens" (`test-token-...`, "Google Account Email / ID Token") from user-facing UI. Replace with clean, standard "Sign In with Google" and "Sign Up with Google (New Account)" workflows accepting user's Gmail address directly. Eliminate the mandatory "Backend Server URL" input from the mobile login screen so mobile users outside localhost don't get stuck. Deploy GitHub Cloud backend architecture using repository `resanul/linkpilot-ai` (`cloud/users.json`, `cloud/licenses.json`, `cloud/config.json`) as a serverless remote registry accessible across any Wi-Fi or mobile data network worldwide without requiring a local running backend server.
- **Components Built**:
  - `cloud/users.json`, `cloud/licenses.json`, `cloud/config.json`: Live remote cloud registry on GitHub main branch.
  - `mobile/lib/services/github_cloud_service.dart`: High-performance GitHub raw cloud client with local SQLite caching, Google account registration, approval verification, and license activation.
  - `mobile/lib/services/api_client.dart`: Integrated automatic transparent fallback to `GitHubCloudService` for `getUserProfile`, `activateLicense`, `getAdminCustomers`, `approveAdminCustomer`, `rejectAdminCustomer`, and `getAdminLicenses`.
  - `mobile/lib/screens/login_screen.dart`: Redesigned UI with dedicated "Sign In with Google" and "Sign Up with Google" flows, live "Backend Cloud: GitHub" status badge, zero token jargon, and collapsed developer settings.
  - `mobile/test/widget_test.dart`: Updated widget tests (14/14 tests passing).

### [TASK-012] Admin Customer License Direct Assignment Engine
- **Objective**: Allow the Administrator to assign/activate a specific commercial license (plan and duration) directly against any customer's email from the Admin Console. Upon assignment, the customer's account is automatically approved, bound to the license, and immediately unlocked so they bypass the key activation prompt and enter their workspace directly.
- **Components Built**:
  - `backend/app/main.py`: Added `POST /admin/customers/{user_id}/assign-license` supporting custom plans (`enterprise`, `business`, `pro`, `standard`) and durations (30d, 60d, 90d, 365d, lifetime) with audit logging (`LICENSE_ASSIGNED_BY_ADMIN`).
  - `mobile/lib/services/github_cloud_service.dart`: Added `adminAssignLicenseToCustomer(userId, plan, billingCycle, durationDays)` with automatic cloud state binding and key generation.
  - `mobile/lib/services/api_client.dart`: Added `assignAdminCustomerLicense(...)` with dual backend/GitHub Cloud support.
  - `mobile/lib/screens/admin/admin_customers_screen.dart`: Added modal bottom sheet with Plan Chips (`Enterprise`, `Business`, `Pro`, `Standard`), Duration Chips (`30 Days`, `60 Days`, `90 Days`, `365 Days`), one-tap "Assign & Activate License" button, quick "Approve" button, and new "Needs License (N)" / "Licensed (N)" filter chips.

### [TASK-013] Proprietary LinkPilot AI Abstraction & Multi-Provider Backend Architecture
- **Objective**: Ensure that customer users never see or manage third-party AI provider keys (Gemini, OpenAI, OpenRouter) or third-party vendor names. All AI engine operations are orchestrated seamlessly by the cloud backend/admin. Customers simply connect their LinkedIn login/token and publish posts.
- **Components Built**:
  - `mobile/lib/screens/settings_screen.dart`: Removed customer-facing Gemini API key card completely. Replaced with a LinkPilot Neural AI Engine active status badge.
  - `mobile/lib/screens/dashboard_screen.dart` & `ai_generator_screen.dart`: Replaced all Gemini vendor mentions with "LinkPilot AI".
  - `mobile/lib/services/api_client.dart`: Refactored `generateAIPost` and `regenerateAIPost` to invoke backend orchestration directly without demanding customer API keys.
  - `backend/app/ai.py`: Added `OpenRouterProvider` and `OpenAIProvider` to `AIProvider` hierarchy alongside `GeminiProvider`. Implemented multi-provider factory in `get_ai_service`.
  - `backend/app/config.py`: Added `openrouter_api_key` and `openai_api_key` settings.
  - `cloud/config.json`: Added `ai_engine` metadata defining LinkPilot Neural Intelligence Engine with backend orchestration.

---

## 🛠️ Problem & Solution Incident Ledger

| Incident ID | Problem Description | Root Cause | Exact Solution Applied |
| :--- | :--- | :--- | :--- |
| **INC-001** | `TypeError: can't subtract offset-naive and offset-aware datetimes` in `app/main.py:230` | SQLite retrieves datetimes without timezone (`tzinfo=None`), failing comparison against `datetime.now(timezone.utc)`. | Normalized all retrieved timestamps with `.replace(tzinfo=timezone.utc)` if naive before performing subtraction or comparison. |
| **INC-002** | `test_expired_license_activation` failed in pytest | The activation handler was overriding pre-existing expired licenses during first-time duration assignment. | Reordered checks to test `item.expires_at < now` prior to setting activation duration. |
| **INC-003** | GitHub `remote: Permission to resanul/linkpilot-ai.git denied (HTTP 403)` | Fine-grained Personal Access Token lacked scope for the newly created repository. | Generated ED25519 SSH key (`~/.ssh/id_ed25519`), registered on GitHub, and switched origin remote to `git@github.com:resanul/linkpilot-ai.git`. |
| **INC-004** | `flutter: command not found` in bash sessions | Non-interactive subshells did not have Flutter or Android SDK in default `PATH`. | Explicitly exported `/home/resanul/flutter/bin`, `ANDROID_HOME=/home/resanul/android-sdk`, and `JAVA_HOME=/home/resanul/jdk-21`. |
| **INC-005** | Duplicate `_promptAdminPin()` inserted in multiple widgets | String replacement matched multiple widget `build()` methods in `dashboard_screen.dart`. | Targeted edit specifically inside `_DashboardScreenState` and removed stray insertions. |
| **INC-006** | Undefined identifier `blue` in `dashboard_screen.dart:163` | Variable `blue` was defined inside a child method rather than at the top of the `build()` method. | Added `const blue = Color(0xFF2563EB);` to the top of `Widget build(BuildContext context)`. |
| **INC-007** | `ApiException.new` positional arguments error in `login_screen.dart` | `ApiException` requires `(int statusCode, String message)`, but only message string was passed. | Updated call to `throw ApiException(403, 'Invalid Master Admin PIN. Access Denied.')`. |
| **INC-008** | Missing Google ID token error when testing direct email login | `security.py` only parsed tokens starting with `test-token-`. | Updated `security.py` to accept any direct email string containing `@` (e.g., `user@gmail.com`) in development mode. |
| **INC-009** | Login screen was never visible on app launch | `splash_screen.dart` had an auto-login bypass that loaded `DashboardScreen` immediately upon launch. | Rewrote `splash_screen.dart` `_checkSession` to navigate directly to `LoginScreen`. |
| **INC-010** | User Dashboard leaked "Admin Portal" toggle button | `dashboard_screen.dart` combined both user and admin views into a single screen with an AppBar switch button. | Decoupled into `DashboardScreen` (pure User) and `AdminPortalScreen` (pure Admin). Removed all admin buttons from the User view. |
| **INC-011** | SQLite schema missing `is_approved` on existing `dev.db` | Adding new columns to SQLAlchemy model does not alter pre-existing SQLite databases automatically. | Added `ensure_db_migrations()` in FastAPI lifespan startup using `PRAGMA table_info(users)` and `ALTER TABLE users ADD COLUMN` if missing. |
| **INC-012** | Mobile client blocked by requirement for local Backend Server URL on real device | Login screen required manual input of `http://10.0.2.2:8001`, which fails on physical hardware outside an emulator. Also exposed raw "token" terminology to non-technical users. | Converted backend architecture to use GitHub Cloud repository (`cloud/users.json`, `cloud/licenses.json`) as a serverless backend accessible from any network. Redesigned LoginScreen with direct Google email input and hidden developer overrides. |
| **INC-013** | Unused element warning on `_approveCustomer` after license bottom sheet integration | Assigning a license auto-approved the customer, leaving the raw approval method uncalled in the UI. | Added a separate "Quick Approve" button next to "Reject" for customers who need verification prior to licensing. |
| **INC-014** | Customer exposure to third-party AI keys eliminated in favor of backend orchestration | Asking customers for Google Gemini keys caused onboarding friction and exposed raw vendor infrastructure. | Stripped all customer-facing AI key inputs; routed AI generation through backend orchestration with OpenRouter, OpenAI, and Gemini support. |

---

## 📊 Current System State & Capabilities Inventory

### 1. Backend Service (`backend/`)
- **Port:** `8001` (running via uvicorn daemon)
- **Database:** SQLite (`backend/dev.db` / `backend/app.db`)
- **Master Admin PIN:** `889900`
- **Endpoints:**
  - `POST /admin/licenses`: Mint licenses (Standard, Pro, Business, Enterprise; 30d, 60d, 90d, 365d, lifetime)
  - `GET /admin/licenses`: List all issued licenses
  - `POST /admin/licenses/{id}/revoke`: Revoke license
  - `GET /admin/customers`: List client users and device allocations
  - `GET /admin/audit-logs`: Audit trail of all activations and connections
  - `POST /license/activate`: Customer key activation
  - `GET /user/profile`: Profile, license plan, and `days_remaining`
  - `POST /posts/sync`: Bi-directional offline sync
  - `POST /ai/generate`: Centralized Google Gemini post generation
  - `POST /linkedin/connect/manual`: LinkedIn access token connection

### 2. Mobile Client (`mobile/`)
- **Flutter Version:** 3.x / Dart 3.x
- **Build Status:** Release APK compiled and verified (`54.6 MB`)
- **Delivery Path:** `DELIVERY/app-release.apk` (with `.sha256` checksum)
- **Target Device:** Nothing Phone (2a) (`Pacman / A142`, `65CICECYGEFQGY69`), Android 16
- **Test Status:** 13/13 Flutter widget/unit tests passing; `flutter analyze` 0 issues.

---

## 🚀 Future Roadmap & Potential Enhancements

### Priority 1: Short-Term Enhancements
1. **Device Fingerprinting & Enforcement**:
   - Store device ID (`android_id` or hardware hash) during license activation.
   - Enforce `max_devices` limit (reject if a second phone attempts to activate the same key without admin approval).
2. **LinkedIn Token Expiry Proactive Alert**:
   - LinkedIn tokens expire every 60 days.
   - Display a countdown badge in User Settings: "LinkedIn Token: 42 days remaining — Re-authenticate".
3. **Image & Carousel Media Support for Posts**:
   - Extend `automation/publish_linkedin.py` and mobile post generator to support image attachments via LinkedIn Assets API.

### Priority 2: Medium-Term Enhancements
4. **AI-Generated Carousel / PDF Slides**:
   - Generate multi-slide cybersecurity cheat sheets (e.g., "5 Steps to Prevent BEC") as PDF carousel slides for LinkedIn.
5. **Team & Agency Multi-Tenant Support**:
   - Allow enterprise customers to manage multiple LinkedIn accounts (company page + personal CEO profile) under one license.
6. **LinkedIn Post Analytics Dashboard**:
   - Fetch post impressions, reactions, and comments using the LinkedIn Analytics REST API.

### Priority 3: Long-Term Vision
7. **Multi-Platform Syndication**:
   - Cross-publish approved cybersecurity content to X/Twitter, Threads, and personal tech blogs.
8. **Fine-Tuned Domain Models**:
   - Implement custom prompt chains trained on real CVEs, MITRE ATT&CK techniques, and CISA advisories.

---

## 📝 Continuous Memory Protocol

Whenever changes are made to this codebase:
1. Update this document (`TASK_MEMORY_AND_CHANGELOG.md`) with the new Task entry under **Historical Task & Feature Ledger**.
2. If any bug or test failure was encountered, document the problem, root cause, and fix under **Problem & Solution Incident Ledger**.
3. Commit this file alongside the code changes to ensure Git contains an uninterrupted record of progress:
   ```bash
   git add TASK_MEMORY_AND_CHANGELOG.md <modified_files>
   git commit -m "feat/fix: <description> & update project memory"
   git push origin main
   ```
