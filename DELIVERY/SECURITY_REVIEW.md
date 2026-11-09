# LinkPilot AI — Security Review & Threat Model

**Application:** LinkPilot AI (Commercial Android Client + FastAPI Backend)  
**Security Posture:** Hardened DevSecOps Architecture  
**Standards:** OWASP Mobile Top 10, OWASP API Security Top 10, CIS Benchmarks  

---

## 1. Security Control Verification Matrix

| Security Domain | Control Implemented | Verification Method | Status |
| :--- | :--- | :--- | :--- |
| **Authentication** | Passwordless Google ID-token validation verifying signature, issuer (`accounts.google.com`), audience (`GOOGLE_CLIENT_ID`), expiry, and `email_verified == true`. | Server-side validation via `google.oauth2.id_token` in `security.py`. Never trusts client-submitted email. | **PASS** |
| **Credential Storage (Client)** | Android Keystore backed storage via `flutter_secure_storage`. No secrets in source, SharedPreferences, or logs. | Validated in `SecureStorageService`. Sensitive tokens isolated in hardware-backed KeyStore. | **PASS** |
| **Token Encryption (Server)** | LinkedIn OAuth access tokens encrypted at rest using Fernet (AES-128-CBC + HMAC-SHA256 authenticated encryption). | Validated via `encrypt_secret` / `decrypt_secret`. Plaintext tokens never persist to disk. | **PASS** |
| **Licensing Integrity** | Commercial license keys stored exclusively as keyed HMAC-SHA256 hashes using server secret `LICENSE_SIGNING_SECRET`. | Plaintext keys are generated with CSPRNG (`secrets.token_urlsafe`), displayed once, and discarded. | **PASS** |
| **Tenant Isolation & IDOR** | Strict ownership binding (`filter_by(user_id=user.id)` applied to all post editing, approval, rejection, and deletion). | Automated test `test_tenant_isolation_and_idor_protection` proved User B cannot access User A's data (returns HTTP 404). | **PASS** |
| **Admin Privilege Boundaries** | Two-tier administrative role segregation (Super Admin vs Staff Admin). Staff cannot revoke licenses, manage staff, or read audit logs. | Verified in `test_admin_and_roles.py`. Role checked dynamically against database and server allowlist. | **PASS** |
| **OAuth CSRF & Replay Defense** | LinkedIn OAuth state parameter generated via CSPRNG (`secrets.token_urlsafe(32)`), stored as SHA-256 hash, bound to user ID, and expiring in 10 minutes. Deleted on single use. | Verified in `test_linkedin_callback_validation_and_replay`. Replay attacks return HTTP 400. | **PASS** |
| **API Abuse & Rate Limiting** | SlowAPI rate limiting enabled on critical endpoints (`/license/activate`, `/linkedin/connect`, `/ai/generate`). | Enforces IP and token-based rate limits to mitigate brute force attacks and AI API exhaustion. | **PASS** |
| **Injection Defense** | SQLAlchemy 2.0 ORM with parameterized SQL queries. Strict Pydantic input models with length bounds. | Zero raw concatenated SQL strings across the entire codebase. | **PASS** |
| **Audit Trails** | Immutable `AuditLog` table capturing actor ID, actor email, action, target type, target ID, and details. | Captures license activations, revocations, staff changes, post approvals, and publications. | **PASS** |
| **Secret Hygiene** | All API keys and secrets loaded exclusively from environment variables. Git repository initialized with strict `.gitignore`. | `.env.example` provides placeholders only; zero live API keys or credentials committed. | **PASS** |

---

## 2. Threat Modeling & Countermeasures

### A. LinkedIn Integration Threat Analysis
- **Risk:** Automated scraping or unauthorized access leading to LinkedIn API restriction.
- **Countermeasure:** LinkPilot AI uses **only official LinkedIn OAuth 2.0** with approved OIDC and `w_member_social` scopes. It does NOT scrape web pages, does NOT intercept cookies, and does NOT request LinkedIn user passwords.
- **Risk:** Token leakage on server compromise.
- **Countermeasure:** All stored LinkedIn access tokens are encrypted using Fernet symmetric encryption. In production, `TOKEN_ENCRYPTION_KEY` can be injected dynamically via AWS KMS, GCP Secret Manager, or HashiCorp Vault.

### B. AI Prompt Injection & Content Integrity
- **Risk:** Malicious customer prompt attempting to generate fake vulnerability disclosures or hallucinatory CVEs.
- **Countermeasure:** The Gemini system prompt enforces strict cybersecurity guidelines: professional human tone, 130–200 words, no fabricated statistics, no fake CVEs, and output sanitization stripping backtick wrappers before database insertion.

### C. Offline Synchronization Conflict Resolution
- **Risk:** Inconsistent state between phone cache and backend scheduler.
- **Countermeasure:** The sync protocol operates on client UUIDs (`client_id`). Server state is authoritative: once a post is `published` or `scheduled` in the cloud, client updates cannot revert it to a draft.
