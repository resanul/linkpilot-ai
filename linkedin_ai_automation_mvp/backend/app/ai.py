import httpx
from fastapi import HTTPException
from .config import settings

async def generate_cybersecurity_post(topic: str = "cybersecurity") -> str:
    if settings.ai_provider.lower() != "gemini":
        raise HTTPException(503, "Configured AI provider is not supported by this adapter")
    if not settings.ai_api_key:
        raise HTTPException(503, "AI provider is not configured")
    prompt = ("Write one original, accurate LinkedIn post in English about cybersecurity. "
              "Topic: " + topic[:200] + ". Use a professional human tone, 120-180 words, "
              "no fabricated statistics or claims, 3-5 relevant hashtags. Return only the post text.")
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{settings.ai_model}:generateContent"
    async with httpx.AsyncClient(timeout=45) as client:
        response = await client.post(url, params={"key": settings.ai_api_key}, json={
            "contents": [{"parts": [{"text": prompt}]}],
            "generationConfig": {"temperature": 0.7, "maxOutputTokens": 500}})
        if response.is_error:
            raise HTTPException(502, "AI generation provider returned an error")
        data = response.json()
    try:
        text = data["candidates"][0]["content"]["parts"][0]["text"].strip()
    except (KeyError, IndexError, TypeError):
        raise HTTPException(502, "AI provider returned an unexpected response")
    if not text:
        raise HTTPException(502, "AI provider returned empty content")
    return text[:3000]
