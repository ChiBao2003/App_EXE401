"""
test_backend_p0_error_handling.py
Kiem thu co lap cac nhanh loi P0 cua /api/v1/pomodoro/sync:
1. update_one nem exception va find_one tra None -> khong duoc tra HTTP 200 (tra HTTP 500 hoac 503).
2. update_one nem exception nhung document da ton tai -> xu ly nhu duplicate (tra HTTP 200 voi doc_id cu).
3. Database timeout nem exception -> tra HTTP 503 Service Unavailable.
KHONG ghi bat ky du lieu nao vao MongoDB that (su dung mock database).
"""
import asyncio
from unittest.mock import AsyncMock, MagicMock
from httpx import AsyncClient, ASGITransport

from main import app
from core.database import get_database
from core.security import get_current_user_id


async def run_p0_backend_error_tests():
    test_user_id = "test_user_p0_mock"
    app.dependency_overrides[get_current_user_id] = lambda: test_user_id

    mock_db = MagicMock()
    mock_pomo_col = MagicMock()
    mock_db.__getitem__.return_value = mock_pomo_col
    app.dependency_overrides[get_database] = lambda: mock_db

    payload = {
        "user_id": test_user_id,
        "session_id": "pomo_2026-10-16T17:00:00_1",
        "hardware_data": {
            "work_min": 25,
            "break_min": 5,
            "pauses": 0,
            "completed": True,
            "session_count": 1,
            "start_time": "2026-10-16T17:00:00",
            "end_time": "2026-10-16T17:25:00",
            "temperature": 26,
        },
        "phone_data": {
            "unlock_count": 0,
            "task_type": "Coding",
            "recommendation_id": None,
            "timestamp": "2026-10-16T17:25:00",
        },
    }

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        print("\n--- TEST 1: update_one nem exception va find_one tra None (LOI GHI DB THAT BAI) ---")
        mock_pomo_col.update_one = AsyncMock(side_effect=Exception("Disk full / Write error"))
        mock_pomo_col.find_one = AsyncMock(return_value=None)

        res1 = await ac.post("/api/v1/pomodoro/sync", json=payload)
        print(f"Status Code tra ve: {res1.status_code}")
        assert res1.status_code == 500, f"Ky vong HTTP 500, thuc te: {res1.status_code}"
        assert res1.status_code != 200, "NGHIEM CAM tra HTTP 200 khi du lieu chua duoc luu!"
        err_detail = res1.json().get("detail", "")
        print(f"Error detail: {err_detail}")
        print("[PASS] Test 1: Khong tra 200 false-positive khi ghi DB that bai!")

        print("\n--- TEST 2: update_one nem exception nhung document DA TON TAI (Retry/Duplicate hop le) ---")
        existing_doc = {
            "_id": "6ad1f2e1aef6dfcbec80a569",
            "user_id": test_user_id,
            "session_id": payload["session_id"],
            "ai_feedback": "Phien da duoc ghi nhan truoc do!",
            "computed": {"actual_work_secs": 1500, "concentration_score": 100.0, "completion_rate": 100.0},
        }
        mock_pomo_col.update_one = AsyncMock(side_effect=Exception("E11000 duplicate key error"))
        mock_pomo_col.find_one = AsyncMock(return_value=existing_doc)

        res2 = await ac.post("/api/v1/pomodoro/sync", json=payload)
        print(f"Status Code tra ve: {res2.status_code}")
        assert res2.status_code == 200, f"Ky vong HTTP 200 cho retry hop le, thuc te: {res2.status_code}"
        data2 = res2.json()
        assert data2["status"] == "ok"
        assert data2["session_id"] == "6ad1f2e1aef6dfcbec80a569"
        print(f"[PASS] Test 2: Retry hop le tra ve dung doc_id cu: {data2['session_id']}")

        print("\n--- TEST 3: DB Timeout nem exception khi update_one va find_one tra None ---")
        mock_pomo_col.update_one = AsyncMock(side_effect=Exception("ServerSelectionTimeoutError: connection timed out"))
        mock_pomo_col.find_one = AsyncMock(return_value=None)

        res3 = await ac.post("/api/v1/pomodoro/sync", json=payload)
        print(f"Status Code tra ve: {res3.status_code}")
        assert res3.status_code == 503, f"Ky vong HTTP 503 khi timeout DB, thuc te: {res3.status_code}"
        print("[PASS] Test 3: Tra ve HTTP 503 Service Unavailable khi DB timeout!")

    app.dependency_overrides.clear()
    print("\n=== ALL BACKEND P0 TESTS PASSED! ===")


if __name__ == "__main__":
    asyncio.run(run_p0_backend_error_tests())
