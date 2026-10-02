import asyncio
import httpx
from datetime import datetime
import sys
import os

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from core.security import create_access_token

BASE_URL = "http://127.0.0.1:8000"

async def test_ai_flow():
    print("STARTING TEST...")
    
    test_user_id = "60c72b2f9b1d8b1f8c123456"
    token = create_access_token({"sub": test_user_id})
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
    
    async with httpx.AsyncClient(base_url=BASE_URL, headers=headers) as client:
        print("2. Asking AI Coach...")
        chat_req = {
            "user_prompt": "Nhận xét thói quen dùng điện thoại của tôi hôm nay, tôi có dùng app giải trí nhiều quá không?",
            "watch_connected": True,
            "lat": 21.0285,
            "lon": 105.8542
        }
        
        res_ai = await client.post("/api/v1/ai/coach/chat", json=chat_req, timeout=60.0)
        if res_ai.status_code == 200:
            print("OK!")
        else:
            print(f"Error calling AI: {res_ai.status_code} - {res_ai.text}")

if __name__ == "__main__":
    asyncio.run(test_ai_flow())
