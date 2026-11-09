# LinkPilot AI 🚀
### Autonomous Cybersecurity LinkedIn Content Engine & SaaS Platform

[![LinkPilot AI - Daily LinkedIn Automation](https://github.com/resanul/linkpilot-ai/actions/workflows/daily_post.yml/badge.svg)](https://github.com/resanul/linkpilot-ai/actions/workflows/daily_post.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Python 3.11+](https://img.shields.io/badge/Python-3.11+-3776AB?logo=python&logoColor=white)](https://www.python.org/)
[![Flutter](https://img.shields.io/badge/Flutter-Android%20App-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)

> 🧠 **Project Memory & Task Changelog**: See [TASK_MEMORY_AND_CHANGELOG.md](TASK_MEMORY_AND_CHANGELOG.md) for the complete chronological task ledger, problem-solution incident records, current system capabilities, and upcoming roadmap.

**LinkPilot AI** is an autonomous content engine designed to build technical cybersecurity authority on LinkedIn without ongoing manual effort. It generates high-engagement, domain-specialized cybersecurity posts and automatically publishes them to LinkedIn on a persistent daily schedule (20:00 Asia/Dhaka / 14:00 UTC).

---

## 🛠️ Project Architecture

| Component | Technology | Description |
| :--- | :--- | :--- |
| **Scheduler** | **GitHub Actions** | Automated cron schedule firing daily at `14:00 UTC` (`20:00 Asia/Dhaka`), plus manual `workflow_dispatch` button. |
| **AI Content** | **Google Gemini** | Generates deep technical posts across 12 cybersecurity domains with anti-duplicate topic rotation. |
| **Content Engine** | **Python** | Formats posts with attention-grabbing hooks, real-world context, technical takeaways, and targeted hashtags. |
| **Database** | **SQLite** | `data/posts.db` persists publishing history and topic hashes; committed back to the repository automatically. |
| **OAuth** | **LinkedIn OAuth 2.0** | Official REST & UGC Posts API with secure token authentication (`w_member_social`). |
| **Hosting** | **GitHub Actions** | 100% serverless and free execution with zero infrastructure costs. |
| **Reports** | **GitHub Actions Logs** | Real-time post previews, status badges, character counts, and URN links in the Job Summary. |

---

## 🛡️ Covered Cybersecurity Domains

LinkPilot AI systematically cycles through 12 core domains to ensure wide topic coverage:
1. **SOC Operations & SIEM** (Detection rules, telemetry, alert triage)
2. **Incident Response & Threat Hunting** (Forensics, living-off-the-land, containment)
3. **Threat Intelligence & MITRE ATT&CK** (TTP mapping, adversary tracking)
4. **Penetration Testing & Red Teaming** (AD Kerberoasting, lateral movement)
5. **Vulnerability Management & AppSec** (EPSS vs CVSS, API security, SBOM)
6. **Cloud Security (AWS / Azure / GCP)** (IAM least privilege, CSPM, K8s)
7. **Network Security & Zero Trust** (Microsegmentation, ZTNA, TLS inspection)
8. **Identity & Access Management (IAM)** (FIDO2, MFA fatigue, PAM, ITDR)
9. **Malware Analysis & Reverse Engineering** (YARA rules, obfuscation, beacons)
10. **Security Awareness & Human Defense** (BEC prevention, vishing, culture)
11. **DevSecOps & Supply Chain Security** (Secrets detection, CI/CD pipelines)
12. **Emerging Cyber Threats & AI Security** (LLM prompt injection, ransomware)

---

## 🚀 Quickstart Guide (3 Steps)

### Step 1: Add GitHub Repository Secrets
Go to your repository: **Settings** ➔ **Secrets and variables** ➔ **Actions** ➔ **New repository secret**:

| Secret Name | Value | How to Get |
| :--- | :--- | :--- |
| `GEMINI_API_KEY` | Your Google Gemini API Key | Get free at [Google AI Studio](https://aistudio.google.com/app/apikey) |
| `LINKEDIN_ACCESS_TOKEN` | 60-day OAuth 2.0 Token | Run the 1-click token generator below |

#### 🔑 Generating Your LinkedIn Access Token
Run this helper script locally on your machine:
```bash
python3 automation/setup_oauth.py
```
1. It opens your browser to LinkedIn's official authorization screen.
2. Click **Allow**.
3. The script displays your 60-day `LINKEDIN_ACCESS_TOKEN` in the terminal.
4. Copy and paste it into GitHub Secrets.

---

### Step 2: Test Post Generation (Dry Run)
You can test the entire pipeline without publishing to LinkedIn:
1. Go to the **Actions** tab on GitHub.
2. Select **LinkPilot AI - Daily LinkedIn Automation**.
3. Click **Run workflow**.
4. Check **Dry run only** (or leave unchecked to post live).
5. View the formatted post and character counts right inside the **Job Summary**!

---

### Step 3: Autonomous Daily Publishing
Once secrets are set, no further action is required:
* The workflow runs automatically every day at **20:00 Bangladesh Time (14:00 UTC)**.
* SQLite records the post to prevent repeating the same topic.
* Updated `data/posts.db` is committed back to the repository automatically.

---

## 📦 Commercial SaaS Platform (Phase 4 Extended)

In addition to this standalone GitHub Actions automation engine, LinkPilot AI also includes the complete commercial SaaS stack:

* **FastAPI Backend** (`/backend`):
  * Alembic database migrations (PostgreSQL + SQLite)
  * HMAC-SHA256 license verification engine (Standard, Pro, Business tiers)
  * Role-Based Access Control (Super Admin, Staff Admin, Customer)
  * Audit logging for every administrative action (`GET /admin/audit-logs`)
  * Bi-directional mobile synchronization endpoint (`POST /posts/sync`)
  * SlowAPI rate limiting & Fernet symmetric token encryption
  * Pytest suite: 19/19 tests passing (`100%`)

* **Flutter Android Mobile Application** (`/mobile`):
  * 11 Customer screens (Dashboard, AI Generator, Post Editor, Approval Queue, Scheduler, History, Settings)
  * 5 Administrative screens (Admin Dashboard, License Minting, Customer Inspector, Staff Roles, Audit Viewer)
  * Offline-first SQLite database (`sqflite`)
  * Flutter test suite: 13/13 tests passing, 0 analyzer warnings
  * Pre-built production release APK (`DELIVERY/app-release.apk`)

---

## 📄 License
This project is licensed under the MIT License.
