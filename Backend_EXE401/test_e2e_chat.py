"""End-to-end test: goi AI Coach chat qua Backend API de kiem tra fallback chain."""
import httpx, asyncio, json

async def main():
    url = "http://127.0.0.1:8000/api/v1/ai/coach/chat"
    payload = {
        "message": "Chào bạn, hôm nay tôi nên làm việc thế nào?",
        "lat": 10.762622,
        "lon": 106.660172
    }

    print("=== TEST AI COACH CHAT (End-to-End) ===")
    try:
        async with httpx.AsyncClient(timeout=90.0) as client:
            resp = await client.post(url, json=payload)
            print(f"Status: {resp.status_code}")
            data = resp.json()
            print(f"\nSource: {data.get('source', 'N/A')}")
            print(f"Reply:\n{data.get('reply', 'NO REPLY')[:500]}")
            if data.get("tool_calls"):
                print(f"\nTool calls: {json.dumps(data['tool_calls'], indent=2)}")
    except Exception as e:
        print(f"Error: {type(e).__name__}: {e}")

asyncio.run(main())
