# LinkPilot AI — Production Deployment Guide & Runbook

This guide covers complete production deployment of the LinkPilot AI FastAPI backend, PostgreSQL database, background worker, Nginx reverse proxy, and Flutter Android client.

---

## 1. Prerequisites & Server Requirements

- **Operating System:** Ubuntu 22.04 LTS / Debian 12 / Kali Linux
- **Compute:** 2 vCPU, 4GB RAM minimum
- **Database:** PostgreSQL 14+ (or managed Amazon RDS / GCP Cloud SQL)
- **Domain:** Dedicated FQDN with DNS A record pointing to the server (e.g., `api.linkpilot.io`)
- **SSL:** TLS 1.3 via Let's Encrypt / Certbot

---

## 2. Environment Configuration (`.env`)

Generate strong cryptographic keys:
```bash
# 1. License signing secret (HMAC-SHA256)
python3 -c "import secrets; print(secrets.token_urlsafe(48))"

# 2. Token encryption key (Fernet AES-256)
python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
```

Create production configuration file `/opt/linkpilot/backend/.env`:
```ini
APP_ENV=production
DATABASE_URL=postgresql+psycopg://linkpilot_user:SECURE_DB_PASSWORD@localhost:5432/linkpilot_prod

# Google OAuth (App Authentication)
GOOGLE_CLIENT_ID=your-google-client-id.apps.googleusercontent.com

# LinkedIn OAuth 2.0 (Official API)
LINKEDIN_CLIENT_ID=your-linkedin-client-id
LINKEDIN_CLIENT_SECRET=your-linkedin-client-secret
LINKEDIN_REDIRECT_URI=https://api.linkpilot.io/linkedin/callback
LINKEDIN_VERSION=202605

# AI Provider (Google Gemini)
AI_PROVIDER=gemini
AI_API_KEY=your-gemini-api-key
AI_MODEL=gemini-2.5-flash

# Security & Encryption
TOKEN_ENCRYPTION_KEY=YOUR_GENERATED_FERNET_KEY
LICENSE_SIGNING_SECRET=YOUR_GENERATED_LICENSE_SECRET

# Administrative Controls
ADMIN_EMAILS=superadmin@linkpilot.io,owner@linkpilot.io
FRONTEND_SUCCESS_URL=https://linkpilot.io/connected
```

---

## 3. Database Migration with Alembic

1. Install dependencies in your virtual environment:
```bash
cd /opt/linkpilot/backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

2. Run Alembic database migrations:
```bash
alembic upgrade head
```

---

## 4. Systemd Service Deployment

Create systemd unit `/etc/systemd/system/linkpilot-api.service`:
```ini
[Unit]
Description=LinkPilot AI FastAPI Backend Service
After=network.target postgresql.service

[Service]
Type=simple
User=linkpilot
Group=linkpilot
WorkingDirectory=/opt/linkpilot/backend
EnvironmentFile=/opt/linkpilot/backend/.env
ExecStart=/opt/linkpilot/backend/.venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8000 --workers 4
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl daemon-reload
sudo systemctl enable linkpilot-api
sudo systemctl start linkpilot-api
sudo systemctl status linkpilot-api
```

---

## 5. Nginx Reverse Proxy & HTTPS Configuration

Create `/etc/nginx/sites-available/linkpilot`:
```nginx
server {
    listen 80;
    server_name api.linkpilot.io;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name api.linkpilot.io;

    ssl_certificate /etc/letsencrypt/live/api.linkpilot.io/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.linkpilot.io/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    # Security Headers
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options DENY;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 60s;
        proxy_connect_timeout 60s;
    }
}
```

Enable site and acquire SSL:
```bash
sudo ln -s /etc/nginx/sites-available/linkpilot /etc/nginx/sites-enabled/
sudo certbot --nginx -d api.linkpilot.io
sudo systemctl restart nginx
```

---

## 6. External Provider Setup

### A. Google OAuth (Application Authentication)
1. In Google Cloud Console, navigate to **APIs & Services > Credentials**.
2. Create **OAuth 2.0 Client ID** (Web application).
3. Set the generated client ID in `GOOGLE_CLIENT_ID`.
4. Ensure Google Sign-In on Android passes the ID token (`idToken`) to the backend.

### B. LinkedIn Developer Portal
1. Create an application at [LinkedIn Developer Portal](https://developer.linkedin.com).
2. Request the **"Share on LinkedIn"** and **"Sign In with LinkedIn using OpenID Connect"** products.
3. Under **Auth Settings**, configure Authorized redirect URLs:
   `https://api.linkpilot.io/linkedin/callback`
4. Copy `Client ID` and `Client Secret` to server `.env`.

### C. Google AI Studio (Gemini API)
1. Generate an API Key at [Google AI Studio](https://aistudio.google.com).
2. Configure `AI_API_KEY` on the backend. Never embed provider keys into the Flutter APK.

---

## 7. Android Release Build

To build the signed release APK targeting your production API endpoint:
```bash
cd mobile
flutter clean
flutter pub get
flutter build apk --release --dart-define=API_BASE_URL=https://api.linkpilot.io
```
Artifact location: `mobile/build/app/outputs/flutter-apk/app-release.apk`
