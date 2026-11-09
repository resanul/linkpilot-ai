import asyncio
from abc import ABC, abstractmethod
import httpx
from fastapi import HTTPException
from .config import settings

VALID_CYBERSECURITY_TOPICS = [
    "SOC operations",
    "SIEM and threat detection",
    "Incident response",
    "Vulnerability management",
    "Penetration testing",
    "Cloud security",
    "Network security",
    "Application security",
    "MITRE ATT&CK",
    "Threat intelligence",
    "Security awareness",
    "Emerging cybersecurity trends"
]

class AIProvider(ABC):
    @abstractmethod
    async def generate_post(self, topic: str) -> str:
        pass

    @abstractmethod
    async def regenerate_post(self, original_body: str, topic: str, instructions: str | None = None) -> str:
        pass

class GeminiProvider(AIProvider):
    def __init__(self, api_key: str, model: str):
        self.api_key = api_key
        self.model = model
        self.base_url = f"https://generativelanguage.googleapis.com/v1beta/models/{self.model}:generateContent"

    async def _call_gemini_with_retry(self, prompt: str, max_retries: int = 3) -> str:
        if not self.api_key:
            raise HTTPException(503, "Gemini API key is not configured on the backend")

        payload = {
            "contents": [{"parts": [{"text": prompt}]}],
            "generationConfig": {
                "temperature": 0.7,
                "maxOutputTokens": 600,
                "topP": 0.95
            }
        }

        last_error = None
        for attempt in range(1, max_retries + 1):
            try:
                async with httpx.AsyncClient(timeout=35.0) as client:
                    response = await client.post(
                        self.base_url,
                        params={"key": self.api_key},
                        json=payload
                    )
                    if response.status_code == 200:
                        data = response.json()
                        candidates = data.get("candidates", [])
                        if not candidates:
                            raise HTTPException(502, "Gemini returned no candidates")
                        parts = candidates[0].get("content", {}).get("parts", [])
                        if not parts:
                            raise HTTPException(502, "Gemini candidate content has no parts")
                        text = parts[0].get("text", "").strip()
                        if not text:
                            raise HTTPException(502, "Gemini generated empty response")
                        # Basic output validation
                        cleaned = text.strip().replace("```markdown", "").replace("```", "")
                        return cleaned[:3000]
                    elif response.status_code in {429, 500, 503, 504}:
                        last_error = f"Gemini API transient error (HTTP {response.status_code}): {response.text}"
                        if attempt < max_retries:
                            await asyncio.sleep(attempt * 1.5)
                            continue
                    else:
                        raise HTTPException(502, f"Gemini API returned HTTP {response.status_code}: {response.text}")
            except httpx.RequestError as exc:
                last_error = f"Network error contacting Gemini: {exc}"
                if attempt < max_retries:
                    await asyncio.sleep(attempt * 1.5)
                    continue

        raise HTTPException(502, f"AI generation failed after {max_retries} attempts: {last_error}")

    async def generate_post(self, topic: str = "cybersecurity") -> str:
        prompt = (
            "You are a Senior DevSecOps and Cybersecurity Specialist creating an engaging, educational "
            "LinkedIn post in English.\n"
            f"Topic: {topic[:200]}\n"
            "Requirements:\n"
            "- Professional, authentic, human tone (avoid generic AI cliches).\n"
            "- Length: 130 to 200 words.\n"
            "- Practical industry insights covering architecture, defense, or operations.\n"
            "- No fabricated statistics, fake CVEs, or false vendor claims.\n"
            "- Include 3 to 5 relevant technical hashtags (e.g., #CyberSecurity #InfoSec #SOC).\n"
            "- Return strictly the final post content without conversational filler."
        )
        return await self._call_gemini_with_retry(prompt)

    async def regenerate_post(self, original_body: str, topic: str, instructions: str | None = None) -> str:
        extra_inst = f"\nSpecific adjustment instructions: {instructions}" if instructions else ""
        prompt = (
            "You are a Senior DevSecOps and Cybersecurity Specialist revising a LinkedIn post.\n"
            f"Original Post:\n\"\"\"{original_body[:2000]}\"\"\"\n"
            f"Domain/Topic: {topic[:200]}{extra_inst}\n"
            "Requirements:\n"
            "- Rewrite and improve the post for clarity, punchiness, and professional depth.\n"
            "- Keep length between 130 and 200 words.\n"
            "- Maintain strict cybersecurity technical accuracy.\n"
            "- Keep 3 to 5 relevant hashtags at the end.\n"
            "- Return only the refined post text."
        )
        return await self._call_gemini_with_retry(prompt)

def get_ai_service(custom_api_key: str | None = None) -> AIProvider:
    provider = settings.ai_provider.lower().strip()
    api_key = custom_api_key or settings.ai_api_key
    if provider == "gemini":
        return GeminiProvider(api_key=api_key, model=settings.ai_model)
    else:
        raise HTTPException(503, f"AI provider '{settings.ai_provider}' is not supported")

async def generate_cybersecurity_post(topic: str = "cybersecurity", custom_api_key: str | None = None) -> str:
    service = get_ai_service(custom_api_key)
    return await service.generate_post(topic)

async def regenerate_cybersecurity_post(original_body: str, topic: str = "cybersecurity", instructions: str | None = None, custom_api_key: str | None = None) -> str:
    service = get_ai_service(custom_api_key)
    return await service.regenerate_post(original_body, topic, instructions)
