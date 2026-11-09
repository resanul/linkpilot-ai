"""LinkPilot AI - Automation Pipeline Runner
Main entry point for GitHub Actions scheduler and local execution.
"""

import os
import sys
from datetime import datetime, timezone

# Add project root and automation folder to python path
current_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, current_dir)

from db import init_db, get_recent_topics, get_recent_domains, record_post, get_stats
from content_engine import generate_post_content
from linkedin import publish_post, LinkedInError


def write_github_summary(topic: str, domain: str, content: str, status: str, post_id: str, error: str = ""):
    """Write an execution report to the GitHub Actions Job Summary."""
    summary_file = os.getenv("GITHUB_STEP_SUMMARY")
    if not summary_file:
        return

    dhaka_time = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")

    status_badge = "✅ **Published Successfully**" if status == "published" else (
        "🧪 **Dry Run Validated**" if status == "dry_run" else f"❌ **Failed**: {error}"
    )

    summary_md = f"""## 🚀 LinkPilot AI — Daily Post Execution Report

| Metric | Value |
| :--- | :--- |
| **Execution Time** | {dhaka_time} |
| **Domain** | `{domain}` |
| **Topic** | {topic} |
| **Status** | {status_badge} |
| **LinkedIn Post ID** | `{post_id or 'N/A'}` |
| **Character Count** | {len(content)} characters |

---

### 📝 Generated Post Content
```text
{content}
```

---
*Automated with LinkPilot AI via GitHub Actions & Google Gemini.*
"""
    try:
        with open(summary_file, "a", encoding="utf-8") as f:
            f.write(summary_md)
    except Exception as e:
        print(f"[-] Could not write to GITHUB_STEP_SUMMARY: {e}")


def main():
    print("=" * 60)
    print("🚀 LinkPilot AI - Daily Autonomous Post Automation")
    print(f"🕒 Timestamp (UTC): {datetime.now(timezone.utc).isoformat()}")
    print("=" * 60)

    # 1. Environment and configuration
    gemini_api_key = os.getenv("GEMINI_API_KEY", "").strip()
    linkedin_token = os.getenv("LINKEDIN_ACCESS_TOKEN", "").strip()
    dry_run_env = os.getenv("DRY_RUN", "false").lower()
    domain_override = os.getenv("DOMAIN_OVERRIDE", "auto").strip()

    is_dry_run = dry_run_env in ("1", "true", "yes")

    # 2. Initialize Database
    init_db()
    recent_topics = get_recent_topics()
    recent_domains = get_recent_domains()

    print(f"[+] Loaded {len(recent_topics)} previous topics from SQLite.")

    # 3. Generate Post Content
    print("[+] Generating cybersecurity content...")
    topic, domain, content, hashtags = generate_post_content(
        api_key=gemini_api_key if gemini_api_key else None,
        recent_topics=recent_topics,
        recent_domains=recent_domains,
        domain_override=domain_override,
    )

    print(f"\n[+] Selected Domain: {domain}")
    print(f"[+] Focus Topic: {topic}")
    print(f"[+] Content Length: {len(content)} characters")
    print("\n" + "-" * 40 + " POST PREVIEW " + "-" * 40)
    print(content)
    print("-" * 94 + "\n")

    # 4. Publish or Dry Run
    status = "published"
    post_id = ""
    error_msg = ""

    if is_dry_run:
        print("[ℹ] DRY_RUN is enabled. Skipping actual LinkedIn API call.")
        status = "dry_run"
        post_id = "dry-run-post-id"
    elif not linkedin_token:
        print("[!] No LINKEDIN_ACCESS_TOKEN provided. Operating in dry-run mode.")
        status = "dry_run"
        post_id = "missing-token-dry-run"
    else:
        print("[+] Publishing to LinkedIn via Official API...")
        try:
            result = publish_post(linkedin_token, content)
            post_id = result.get("post_id", "")
            print(f"✅ Published successfully! LinkedIn ID: {post_id}")
        except LinkedInError as e:
            print(f"❌ Publishing error: {e}")
            status = "failed"
            error_msg = str(e)
        except Exception as e:
            print(f"❌ Unexpected error during publish: {e}")
            status = "failed"
            error_msg = str(e)

    # 5. Record to Database
    record_id = record_post(
        topic=topic,
        domain=domain,
        content=content,
        hashtags=hashtags,
        status=status,
        linkedin_post_id=post_id,
        error_message=error_msg,
    )
    print(f"[+] Recorded in SQLite database with ID: {record_id}")

    # 6. Write GitHub Summary
    write_github_summary(
        topic=topic,
        domain=domain,
        content=content,
        status=status,
        post_id=post_id,
        error=error_msg,
    )

    # 7. Print stats
    stats = get_stats()
    print("\n📊 Database Statistics:")
    print(f"   • Total Published: {stats['total_published']}")
    print(f"   • Total Failed: {stats['total_failed']}")
    print(f"   • Top Domains Covered: {list(stats['domain_breakdown'].keys())[:3]}")

    if status == "failed":
        sys.exit(1)


if __name__ == "__main__":
    main()
