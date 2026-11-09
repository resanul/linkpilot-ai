# LinkPilot AI — Known Issues & External Dependencies

**Version:** 1.0.0 Commercial Release  
**Date:** November 9, 2026  

---

## 1. External Third-Party Integration Prerequisites

| Dependency | Required External Action | Impact on System if Unconfigured |
| :--- | :--- | :--- |
| **LinkedIn Developer App Approval** | Application must be approved by LinkedIn for "Share on LinkedIn" and "Sign In with LinkedIn using OpenID Connect" products with `w_member_social` permission. | Post publishing fails closed with HTTP 502/503. The backend safely catches this error, marks post status as `failed`, records the error detail, and prevents duplicate retries. |
| **Google Cloud OAuth 2.0 Credentials** | Production `GOOGLE_CLIENT_ID` must be configured in server environment. Android app package name (`com.linkpilot.ai.linkedin_ai_automation`) and SHA-1 signing fingerprint must be registered in Google Cloud Console. | In test/dev environments, the QA test token bypass (`test-token-...`) allows full functional verification without live GCP client configuration. In production, unverified tokens return HTTP 401. |
| **Google Gemini API Key** | Valid API key from Google AI Studio configured in backend `.env` as `AI_API_KEY`. | AI generation endpoint returns HTTP 503 ("AI provider is not configured"). Client displays an informative banner. |
| **Production SMS/Email Gateway** | Not included in this MVP tier. Staff invites and license key deliveries are performed out-of-band by Super Admins. | License keys must be copied from the Admin Panel and securely communicated to customers. |

---

## 2. Platform & Operational Limitations

1. **Single LinkedIn Account per Customer:**  
   Per commercial product design, each LinkPilot customer connects exactly one official LinkedIn personal account. Multi-profile switching for a single customer identity is intentionally unsupported in this release tier.
2. **Feed Reading & Arbitrary Auto-Commenting:**  
   In compliance with LinkedIn API policies and privacy terms, arbitrary automated feed crawling, mass commenting, and scraping are strictly excluded. Publishing is restricted to original authorized thought leadership commentary on the member's profile feed.
3. **Database Migration Precedence:**  
   Always run `alembic upgrade head` before launching production FastAPI workers against existing databases. Do not rely on SQLAlchemy `create_all()` to alter existing PostgreSQL schemas.
