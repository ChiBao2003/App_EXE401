"""Test gemini-3.8-flash specifically with both auth methods."""
import os, httpx, asyncio
from dotenv import load_dotenv

load_dotenv()
key = os.getenv("GEMINI_API_KEY", "")

async def main():
    payload = {
        "contents": [{"role": "user", "parts": [{"text": "Hello, reply 'OK'"}]}],
        "generationConfig": {"maxOutputTokens": 10}
    }

    # Test 1: x-goog-api-key header
    print("=== Test 1: gemini-3.8-flash + x-goog-api-key header ===")
    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            resp = await client.post(
                "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent",
                json=payload,
                headers={"Content-Type": "application/json", "x-goog-api-key": key}
            )
            print(f"Status: {resp.status_code}")
            print(f"Body: {resp.text[:500]}")
    except Exception as e:
        print(f"Error: {e}")
    
    print()

    # Test 2: ?key= query param
    print("=== Test 2: gemini-3.8-flash + ?key= query param ===")
    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            resp = await client.post(
                f"https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent?key={key}",
                json=payload,
                headers={"Content-Type": "application/json"}
            )
            print(f"Status: {resp.status_code}")
            print(f"Body: {resp.text[:500]}")
    except Exception as e:
        print(f"Error: {e}")

asyncio.run(main())
