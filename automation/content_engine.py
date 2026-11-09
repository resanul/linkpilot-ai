"""LinkPilot AI - Cybersecurity Content Engine
Generates professional English cybersecurity posts across 12 specialized domains
using the Google Gemini API with built-in domain rotation and fallback support.
"""

import os
import random
import re
import requests
import time
from typing import Dict, List, Optional, Tuple

CYBERSECURITY_DOMAINS = [
    {
        "name": "SOC Operations & SIEM",
        "keywords": ["SIEM correlation rules", "alert triage fatigue", "false positive reduction", "SOC tier 1-3 workflow", "EDR telemetry"],
        "hashtags": ["#SOC", "#SIEM", "#CyberSecurity", "#BlueTeam", "#InfoSec"],
    },
    {
        "name": "Incident Response & Threat Hunting",
        "keywords": ["containment strategies", "memory forensics", "hunting living-off-the-land (LotL) binaries", "incident tabletop exercises", "ransomware containment"],
        "hashtags": ["#IncidentResponse", "#ThreatHunting", "#DFIR", "#BlueTeam", "#CyberDefense"],
    },
    {
        "name": "Threat Intelligence & MITRE ATT&CK",
        "keywords": ["TTP mapping", "IOC vs TTP pivot", "threat actor tracking", "C2 infrastructure identification", "cyber threat intelligence (CTI) sharing"],
        "hashtags": ["#ThreatIntel", "#MITREATTACK", "#CyberThreats", "#ThreatDetection", "#InfoSec"],
    },
    {
        "name": "Penetration Testing & Red Teaming",
        "keywords": ["Active Directory Kerberoasting", "privilege escalation vectors", "perimeter reconnaissance", "phishing simulation resilience", "post-exploitation lateral movement"],
        "hashtags": ["#PenTesting", "#RedTeam", "#OffensiveSecurity", "#EthicalHacking", "#CyberSec"],
    },
    {
        "name": "Vulnerability Management & AppSec",
        "keywords": ["patch prioritization risk scoring (EPSS vs CVSS)", "software bill of materials (SBOM)", "API security OWASP Top 10", "DAST vs SAST in CI/CD", "zero-day triage"],
        "hashtags": ["#AppSec", "#VulnerabilityManagement", "#DevSecOps", "#SecureCoding", "#CyberSecurity"],
    },
    {
        "name": "Cloud Security (AWS, Azure, GCP)",
        "keywords": ["IAM least privilege misconfigurations", "cloud security posture management (CSPM)", "S3 bucket & blob security", "Kubernetes cluster hardening", "cloud audit logging"],
        "hashtags": ["#CloudSecurity", "#AWSSecurity", "#AzureSecurity", "#Kubernetes", "#DevSecOps"],
    },
    {
        "name": "Network Security & Zero Trust",
        "keywords": ["microsegmentation architecture", "TLS inspection challenges", "Zero Trust Network Access (ZTNA)", "DNS security & sinkholing", "firewall policy bloat"],
        "hashtags": ["#ZeroTrust", "#NetworkSecurity", "#CyberArchitecture", "#InfoSec", "#CyberDefense"],
    },
    {
        "name": "Identity & Access Management (IAM)",
        "keywords": ["FIDO2 & passkeys adoption", "MFA fatigue attacks", "privileged access management (PAM)", "session token hijacking", "identity threat detection (ITDR)"],
        "hashtags": ["#IAM", "#IdentitySecurity", "#ZeroTrust", "#MFA", "#CyberSecurity"],
    },
    {
        "name": "Malware Analysis & Reverse Engineering",
        "keywords": ["payload obfuscation & packing", "sandbox evasion techniques", "malware beaconing patterns", "process hollowing detection", "YARA rule crafting"],
        "hashtags": ["#MalwareAnalysis", "#ReverseEngineering", "#ThreatHunting", "#DFIR", "#BlueTeam"],
    },
    {
        "name": "Security Awareness & Social Engineering Defense",
        "keywords": ["business email compromise (BEC)", "vishing & deepfake audio threats", "credential harvesting landing pages", "building a security-first culture", "just-in-time micro-training"],
        "hashtags": ["#SecurityAwareness", "#SocialEngineering", "#HumanFirewall", "#PhishingDefense", "#InfoSec"],
    },
    {
        "name": "DevSecOps & Supply Chain Security",
        "keywords": ["secrets detection in git repositories", "dependency confusion attacks", "infrastructure as code (IaC) linting", "signed container images", "shifting left without slowing down"],
        "hashtags": ["#DevSecOps", "#SupplyChainSecurity", "#AppSec", "#CI_CD", "#CyberSecurity"],
    },
    {
        "name": "Emerging Cyber Threats & AI Security",
        "keywords": ["prompt injection in enterprise LLMs", "AI-accelerated vulnerability discovery", "ransomware data exfiltration extortion", "quantum-resistant cryptography preparation", "shadow AI detection"],
        "hashtags": ["#AISecurity", "#CyberTrends", "#FutureOfCyber", "#Ransomware", "#TechTrends"],
    },
]


def select_domain(recent_domains: List[str], override: Optional[str] = None) -> Dict[str, Any]:
    """Select a cybersecurity domain, avoiding recently covered domains for variety."""
    if override and override.lower() != "auto":
        for d in CYBERSECURITY_DOMAINS:
            if override.lower() in d["name"].lower():
                return d

    # Filter out domains that were used in the last 4 posts
    available = [d for d in CYBERSECURITY_DOMAINS if d["name"] not in recent_domains[:4]]
    if not available:
        available = CYBERSECURITY_DOMAINS

    return random.choice(available)


def generate_post_content(
    api_key: Optional[str] = None,
    recent_topics: Optional[List[str]] = None,
    recent_domains: Optional[List[str]] = None,
    domain_override: Optional[str] = None,
) -> Tuple[str, str, str, str]:
    """
    Generate an engaging cybersecurity LinkedIn post.
    Returns: (topic, domain_name, post_body, hashtags)
    """
    recent_topics = recent_topics or []
    recent_domains = recent_domains or []

    selected_domain = select_domain(recent_domains, domain_override)
    domain_name = selected_domain["name"]
    keyword = random.choice(selected_domain["keywords"])
    default_hashtags = " ".join(selected_domain["hashtags"])

    topic = f"{keyword} in modern enterprise defense"

    # If no API key is provided, use the high-quality template generator
    if not api_key:
        print("[!] No GEMINI_API_KEY provided. Using deterministic cybersecurity content engine.")
        content = _generate_template_post(domain_name, keyword, default_hashtags)
        return (topic, domain_name, content, default_hashtags)

    prompt = f"""
You are a Principal Cybersecurity Architect and influential LinkedIn thought leader.
Write a compelling, professional, and practical LinkedIn post focused on:

Domain: {domain_name}
Specific Focus Topic: {keyword}

Requirements:
1. Hook: Start with a powerful 1-2 sentence opening hook that grabs cybersecurity professionals (CISOs, SOC leads, SecOps engineers).
2. The Challenge: Briefly explain the core practical problem or emerging risk in 2-3 sentences.
3. Actionable Insights: Provide 3-4 concise, bulleted technical takeaways, architectural recommendations, or actionable triage steps (use clean emojis or dashes).
4. Engagement Question: End with an open-ended question inviting peers and community members to share their perspectives or experiences.
5. Hashtags: End with 4-5 relevant hashtags (include #CyberSecurity #InfoSec).
6. Tone: Authoritative, pragmatic, no fluff, no buzzword overload. Keep length strictly between 800 and 1,400 characters for optimal LinkedIn engagement.
7. Avoid repeating these recently covered topics: {", ".join(recent_topics[:10]) if recent_topics else "None"}.

Format the post directly as plain text suitable for direct copy-paste into LinkedIn. Do NOT enclose in markdown quotes.
"""

    # Call Gemini API with bounded retries
    models = ["gemini-1.5-flash", "gemini-2.0-flash", "gemini-2.5-flash"]
    api_url = "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={key}"

    last_error = None
    for model in models:
        endpoint = api_url.format(model=model, key=api_key)
        payload = {
            "contents": [{"parts": [{"text": prompt}]}],
            "generationConfig": {
                "temperature": 0.7,
                "maxOutputTokens": 1000,
            },
        }

        for attempt in range(2):
            try:
                response = requests.post(endpoint, json=payload, timeout=25)
                if response.status_code == 200:
                    data = response.json()
                    candidates = data.get("candidates", [])
                    if candidates:
                        raw_text = candidates[0]["content"]["parts"][0]["text"].strip()
                        # Extract hashtags from text
                        hashtags_found = re.findall(r"#\w+", raw_text)
                        hashtags_str = " ".join(hashtags_found[:5]) if hashtags_found else default_hashtags
                        return (topic, domain_name, raw_text, hashtags_str)
                elif response.status_code == 404:
                    # Model not available in this tier, try next model
                    break
                else:
                    last_error = f"API {response.status_code}: {response.text[:120]}"
            except Exception as e:
                last_error = str(e)
            time.sleep(2)

    print(f"[!] Gemini generation failed ({last_error}). Falling back to robust template engine.")
    content = _generate_template_post(domain_name, keyword, default_hashtags)
    return (topic, domain_name, content, default_hashtags)


def _generate_template_post(domain: str, keyword: str, hashtags: str) -> str:
    """Fallback generator for guaranteed 100% reliable post creation."""
    return f"""🚨 Why {keyword} is making or breaking modern enterprise security:

Too many security operations teams still treat this as an afterthought until an active adversary exposes the gap. Here is what separates mature security programs from reactive ones:

🔹 Context Over Volume: Telemetry without contextual asset classification leads straight to alert fatigue and missed pivots.
🔹 Shift From Indicators to Behaviors: IOCs expire in hours; adversary TTPs mapped to MITRE ATT&CK persist across campaigns.
🔹 Continuous Validation: If your detection or prevention controls aren't validated against simulated attacks weekly, assume they don't work.
🔹 Clear Escalation Playbooks: Speed of containment dictates the eventual breach blast radius.

What is the biggest operational hurdle your team faces with {keyword} today?

Share your thoughts in the comments! 👇

{hashtags}"""
