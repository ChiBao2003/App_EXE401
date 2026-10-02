"""Quick diagnostic script to test the Gemini API key and model."""
import os
import httpx
import asyncio
from dotenv import load_dotenv

load_dotenv()

key = os.getenv("GEMINI_API_KEY", "")
print(f"=== GEMINI API KEY DIAGNOSTIC ===")
print(f"Key length: {len(key)}")
print(f"Key prefix: {key[:10]}...")
print(f"Key starts with AIza: {key.startswith('AIza')}")
print()

# Test models
MODELS_TO_TEST = [
    "gemini-2.0-flash",
    "gemini-2.5-flash", 
    "gemini-1.5-flash",
]

async def test_model(model_name: str, use_header: bool = True):
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model_name}:generateContent"
    payload = {
        "contents": [{"role": "user", "parts": [{"text": "Hello, reply with just 'OK'"}]}],
        "generationConfig": {"maxOutputTokens": 10}
    }
    
    if use_header:
        headers = {"Content-Type": "application/json", "x-goog-api-key": key}
        full_url = url
    else:
        headers = {"Content-Type": "application/json"}
        full_url = f"{url}?key={key}"
    
    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            resp = await client.post(full_url, json=payload, headers=headers)
            if resp.status_code == 200:
                data = resp.json()
                text = data.get("candidates", [{}])[0].get("content", {}).get("parts", [{}])[0].get("text", "")
                print(f"  [OK] {model_name} (header={use_header}) -> {resp.status_code} -> '{text.strip()}'")
                return True
            else:
                print(f"  [FAIL] {model_name} (header={use_header}) -> {resp.status_code}: {resp.text[:200]}")
                return False
    except Exception as e:
        print(f"  [ERROR] {model_name} (header={use_header}) -> {type(e).__name__}: {e}")
        return False

async def main():
    print("=== TESTING MODELS WITH x-goog-api-key HEADER ===")
    for m in MODELS_TO_TEST:
        await test_model(m, use_header=True)
    
    print()
    print("=== TESTING MODELS WITH ?key= QUERY PARAM ===")
    for m in MODELS_TO_TEST:
        await test_model(m, use_header=False)

asyncio.run(main())
