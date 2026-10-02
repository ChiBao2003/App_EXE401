"""Simulate the exact same call the AICoachOrchestrator makes."""
import os, httpx, asyncio, json
from dotenv import load_dotenv

load_dotenv()
key = os.getenv("GEMINI_API_KEY", "")

async def main():
    payload = {
        "system_instruction": {
            "parts": [{"text": "You are Kilo Coach, an AI assistant. Reply briefly in Vietnamese."}]
        },
        "contents": [{"role": "user", "parts": [{"text": "Hello, ban la ai?"}]}],
        "generationConfig": {
            "temperature": 0.4,
            "maxOutputTokens": 8192,
            "candidateCount": 1
        }
    }

    print("=== Calling gemini-3.8-flash with real payload ===")
    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            resp = await client.post(
                "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent",
                json=payload,
                headers={
                    "Content-Type": "application/json",
                    "x-goog-api-key": key
                }
            )
            print(f"Status: {resp.status_code}")
            data = resp.json()
            print(f"Full response: {json.dumps(data, indent=2, ensure_ascii=False)[:2000]}")
            
            # Parse like orchestrator does
            candidates = data.get("candidates", [])
            if candidates:
                parts = candidates[0].get("content", {}).get("parts", [])
                print(f"\n=== PARSED PARTS ===")
                for i, part in enumerate(parts):
                    print(f"Part {i}: {json.dumps(part, ensure_ascii=False)[:500]}")
                    if "text" in part:
                        print(f"  -> TEXT FOUND: {part['text'][:300]}")
                    elif "functionCall" in part:
                        print(f"  -> FUNCTION CALL: {part['functionCall']}")
            else:
                print("NO CANDIDATES FOUND!")
                
    except Exception as e:
        print(f"Error: {type(e).__name__}: {e}")

asyncio.run(main())
