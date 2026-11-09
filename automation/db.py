"""LinkPilot AI - SQLite Database Tracker
Handles local post history, duplicate topic prevention, and publishing records.
"""

import os
import sqlite3
from datetime import datetime, timezone
from typing import List, Dict, Optional, Any

DEFAULT_DB_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "data", "posts.db"
)


def get_connection(db_path: str = DEFAULT_DB_PATH) -> sqlite3.Connection:
    os.makedirs(os.path.dirname(db_path), exist_ok=True)
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    return conn


def init_db(db_path: str = DEFAULT_DB_PATH) -> None:
    """Initialize the SQLite posts tracking database."""
    conn = get_connection(db_path)
    with conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS posts (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                topic TEXT NOT NULL,
                domain TEXT NOT NULL,
                content TEXT NOT NULL,
                hashtags TEXT NOT NULL,
                status TEXT NOT NULL,
                linkedin_post_id TEXT,
                error_message TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
            """
        )
        conn.execute("CREATE INDEX IF NOT EXISTS idx_posts_domain ON posts(domain)")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_posts_status ON posts(status)")
    conn.close()


def get_recent_topics(db_path: str = DEFAULT_DB_PATH, limit: int = 30) -> List[str]:
    """Retrieve recent post topics to avoid duplicate generation."""
    conn = get_connection(db_path)
    cursor = conn.cursor()
    cursor.execute(
        "SELECT topic FROM posts WHERE status = 'published' ORDER BY id DESC LIMIT ?",
        (limit,),
    )
    rows = cursor.fetchall()
    conn.close()
    return [row["topic"] for row in rows]


def get_recent_domains(db_path: str = DEFAULT_DB_PATH, limit: int = 5) -> List[str]:
    """Retrieve recently covered domains to encourage diverse topic rotation."""
    conn = get_connection(db_path)
    cursor = conn.cursor()
    cursor.execute(
        "SELECT domain FROM posts WHERE status = 'published' ORDER BY id DESC LIMIT ?",
        (limit,),
    )
    rows = cursor.fetchall()
    conn.close()
    return [row["domain"] for row in rows]


def record_post(
    db_path: str = DEFAULT_DB_PATH,
    topic: str = "",
    domain: str = "",
    content: str = "",
    hashtags: str = "",
    status: str = "published",
    linkedin_post_id: Optional[str] = None,
    error_message: Optional[str] = None,
) -> int:
    """Record a newly generated/published post in the database."""
    conn = get_connection(db_path)
    with conn:
        cursor = conn.cursor()
        cursor.execute(
            """
            INSERT INTO posts (topic, domain, content, hashtags, status, linkedin_post_id, error_message, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                topic,
                domain,
                content,
                hashtags,
                status,
                linkedin_post_id,
                error_message,
                datetime.now(timezone.utc).isoformat(),
            ),
        )
        post_id = cursor.lastrowid
    conn.close()
    return post_id or 0


def get_stats(db_path: str = DEFAULT_DB_PATH) -> Dict[str, Any]:
    """Retrieve publishing statistics."""
    conn = get_connection(db_path)
    cursor = conn.cursor()
    cursor.execute("SELECT COUNT(*) AS total FROM posts WHERE status = 'published'")
    total_published = cursor.fetchone()["total"]

    cursor.execute("SELECT COUNT(*) AS total FROM posts WHERE status = 'failed'")
    total_failed = cursor.fetchone()["total"]

    cursor.execute(
        "SELECT domain, COUNT(*) AS count FROM posts WHERE status = 'published' GROUP BY domain ORDER BY count DESC"
    )
    domain_breakdown = {row["domain"]: row["count"] for row in cursor.fetchall()}

    cursor.execute(
        "SELECT * FROM posts WHERE status = 'published' ORDER BY id DESC LIMIT 1"
    )
    last_post = cursor.fetchone()

    conn.close()
    return {
        "total_published": total_published,
        "total_failed": total_failed,
        "domain_breakdown": domain_breakdown,
        "last_post": dict(last_post) if last_post else None,
    }
