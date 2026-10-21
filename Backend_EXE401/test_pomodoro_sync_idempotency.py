"""
test_pomodoro_sync_idempotency.py
Kiem tra toan dien co che chong ghi trung (Idempotency), Unique Index,
xu ly retry va dong thoi (concurrency) tren endpoint /api/v1/pomodoro/sync.
"""
import asyncio
import os
from httpx import AsyncClient, ASGITransport
from motor.motor_asyncio import AsyncIOMotorClient

from main import app
from core.database import get_database, init_db_indexes, MONGO_URI, DATABASE_NAME
async def test_pomodoro_sync_idempotency_suite():
    # 1. Ket noi MongoDB that va khoi tao indexes
    client = AsyncIOMotorClient(MONGO_URI)
    db = client[DATABASE_NAME]
    await init_db_indexes()

    test_user_id = "test_user_idempotency_audit"
    session_id_1 = "pomo_2026-10-16T15:00:00_1"
    session_id_2 = "pomo_2026-10-16T16:00:00_2"

    # Don dep du lieu test cu (neu co)
    await db["pomodoro_sessions"].delete_many({"user_id": test_user_id})
    await db["productivity_logs"].delete_many({"user_id": test_user_id})

    payload_session_1 = {
        "user_id": test_user_id,
        "session_id": session_id_1,
        "hardware_data": {
            "work_min": 25,
            "break_min": 5,
            "pauses": 1,
            "completed": True,
            "session_count": 1,
            "start_time": "2026-10-16T15:00:00",
            "end_time": "2026-10-16T15:25:00",
            "temperature": 28,
        },
        "phone_data": {
            "unlock_count": 0,
            "task_type": "Coding",
            "recommendation_id": None,
            "timestamp": "2026-10-16T15:25:05",
        },
    }

    # Override dependency auth de test khong can JWT
    from core.security import get_current_user_id
    app.dependency_overrides[get_current_user_id] = lambda: test_user_id
    app.dependency_overrides[get_database] = lambda: db

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        print("\n--- TEST 1: Gui cung mot session lan 1 (First Ingestion) ---")
        res1 = await ac.post("/api/v1/pomodoro/sync", json=payload_session_1)
        assert res1.status_code == 200, f"Status code: {res1.status_code}"
        data1 = res1.json()
        assert data1["status"] == "ok"
        first_doc_id = data1["session_id"]
        print(f"Lan 1 thanh cong, doc_id: {first_doc_id}")

        print("\n--- TEST 2: Gui lai cung mot session lan 2 (Flutter Retry / Timeout) ---")
        res2 = await ac.post("/api/v1/pomodoro/sync", json=payload_session_1)
        assert res2.status_code == 200, f"Status code: {res2.status_code}"
        data2 = res2.json()
        assert data2["status"] == "ok"
        assert data2["session_id"] == first_doc_id, "doc_id phai trung khop voi lan 1"
        assert data2["feedback"] == data1["feedback"]
        print(f"Lan 2 nhan dien trung lap thanh cong, giu nguyen doc_id: {data2['session_id']}")

        print("\n--- TEST 3: Xac minh so luong document trong database ---")
        scoped_id_1 = f"pomo_{test_user_id}_{session_id_1[5:]}"
        count_sessions = await db["pomodoro_sessions"].count_documents({"user_id": test_user_id, "session_id": scoped_id_1})
        assert count_sessions == 1, f"Ky vong 1 document pomodoro_sessions voi scoped session_id, thuc te: {count_sessions}"

        count_hw = await db["pomodoro_sessions"].count_documents({"user_id": test_user_id, "hardware_session_id": session_id_1})
        assert count_hw == 1, f"Ky vong 1 document voi hardware_session_id, thuc te: {count_hw}"

        count_logs = await db["productivity_logs"].count_documents({"user_id": test_user_id, "session_id": first_doc_id})
        assert count_logs == 1, f"Ky vong 1 log productivity_logs, thuc te: {count_logs}"
        print(f"Xac minh: duy nhat 1 document pomodoro_sessions va 1 document productivity_logs!")

        print("\n--- TEST 4: Gui 2 request dong thoi cho cung mot session (Race Condition) ---")
        session_id_race = "pomo_2026-10-16T17:00:00_99"
        payload_race = dict(payload_session_1)
        payload_race["session_id"] = session_id_race
        payload_race["hardware_data"] = dict(payload_session_1["hardware_data"])
        payload_race["hardware_data"]["start_time"] = "2026-10-16T17:00:00"

        # Ban 2 request song song cung mot luc
        results = await asyncio.gather(
            ac.post("/api/v1/pomodoro/sync", json=payload_race),
            ac.post("/api/v1/pomodoro/sync", json=payload_race)
        )
        assert results[0].status_code == 200
        assert results[1].status_code == 200
        scoped_race = f"pomo_{test_user_id}_{session_id_race[5:]}"
        race_count = await db["pomodoro_sessions"].count_documents({"user_id": test_user_id, "session_id": scoped_race})
        assert race_count == 1, f"Race condition failed! Found {race_count} documents for same session"
        print("Test Race Condition DAT: 2 request dong thoi chi tao dung 1 document duy nhat!")

        print("\n--- TEST 5: Session khac nhau phai duoc luu doc lap ---")
        payload_session_2 = dict(payload_session_1)
        payload_session_2["session_id"] = session_id_2
        payload_session_2["hardware_data"] = dict(payload_session_1["hardware_data"])
        payload_session_2["hardware_data"]["start_time"] = "2026-10-16T16:00:00"
        payload_session_2["hardware_data"]["session_count"] = 2

        res3 = await ac.post("/api/v1/pomodoro/sync", json=payload_session_2)
        assert res3.status_code == 200
        total_user_sessions = await db["pomodoro_sessions"].count_documents({"user_id": test_user_id})
        assert total_user_sessions == 3, f"Ky vong 3 sessions tong cong (session 1, race, session 2), thuc te: {total_user_sessions}"
        print("Test luu cac session doc lap DAT!")

        # Don dep du lieu test
        await db["pomodoro_sessions"].delete_many({"user_id": test_user_id})
        await db["productivity_logs"].delete_many({"user_id": test_user_id})

    app.dependency_overrides.clear()
    client.close()
    print("\nALL IDEMPOTENCY & DEDUPLICATION TESTS PASSED!")

if __name__ == "__main__":
    asyncio.run(test_pomodoro_sync_idempotency_suite())
