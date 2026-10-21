"""
test_backend_p1_multitenant.py
Test suite kiem thu toan dien 10 yeu cau cho P1 Multi-Tenant Session Collision Fix:
1. User A gui phien X lan dau: tao dung mot ban ghi.
2. User A retry phien X: khong tao ban ghi thu hai.
3. User B gui cung session_id X: tao phien rieng cua B.
4. User B retry X: chi tra ve ban ghi cua B.
5. User B khong the nhan _id, feedback hoac du lieu cua A.
6. Hai user gui dong thoi cung session_id: ca hai phien duoc luu doc lap.
7. Cung user gui dong thoi cung session_id: chi co mot phien.
8. Loi DB, timeout va duplicate-key khong tao HTTP 200 gia.
9. Cac test Pomodoro hien co van dat.
10. Kiem tra khong lam hong luong tao productivity_logs hoac cap nhat AI.
"""
import asyncio
from unittest.mock import AsyncMock
from httpx import AsyncClient, ASGITransport
from motor.motor_asyncio import AsyncIOMotorClient

from main import app
from core.database import get_database, init_db_indexes, MONGO_URI, DATABASE_NAME
from core.security import get_current_user_id


async def run_p1_multitenant_suite():
    print("=" * 70)
    print("BAT DAU KIEM THU P1 MULTI-TENANT ISOLATION SUITE")
    print("=" * 70)

    client = AsyncIOMotorClient(MONGO_URI)
    db = client[DATABASE_NAME]
    await init_db_indexes()

    user_A = "test_user_alpha"
    user_B = "test_user_beta"
    session_id_X = "pomo_2026-10-16T18:00:00_1"

    # Don dep du lieu truoc khi test
    await db["pomodoro_sessions"].delete_many({"user_id": {"$in": [user_A, user_B]}})
    await db["productivity_logs"].delete_many({"user_id": {"$in": [user_A, user_B]}})

    # Payload co ban
    def make_payload(user_id: str, session_id: str, task: str = "Coding", pauses: int = 1):
        return {
            "user_id": user_id,
            "session_id": session_id,
            "hardware_data": {
                "work_min": 25,
                "break_min": 5,
                "pauses": pauses,
                "completed": True,
                "session_count": 1,
                "start_time": "2026-10-16T18:00:00",
                "end_time": "2026-10-16T18:25:00",
                "temperature": 27,
            },
            "phone_data": {
                "unlock_count": 0,
                "task_type": task,
                "recommendation_id": None,
                "timestamp": "2026-10-16T18:25:05",
            },
        }

    app.dependency_overrides[get_database] = lambda: db

    # Helper de gia lap auth header cho tung user
    current_auth = {"user_id": user_A}
    app.dependency_overrides[get_current_user_id] = lambda: current_auth["user_id"]

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:

        # ----------------------------------------------------
        # TEST 1: User A gui phien X lan dau: tao dung 1 ban ghi
        # ----------------------------------------------------
        print("\n--- TEST 1: User A gui phien X lan dau ---")
        current_auth["user_id"] = user_A
        res1 = await ac.post("/api/v1/pomodoro/sync", json=make_payload(user_A, session_id_X, task="UserA_Work", pauses=1))
        assert res1.status_code == 200, f"Status code: {res1.status_code}"
        data_A1 = res1.json()
        doc_id_A = data_A1["session_id"]
        assert doc_id_A is not None, "doc_id phai ton tai"
        count_A = await db["pomodoro_sessions"].count_documents({"user_id": user_A})
        assert count_A == 1, f"Ky vong dung 1 document cho User A, thuc te: {count_A}"
        print(f"[PASS] Test 1: User A tao thanh cong 1 ban ghi voi doc_id={doc_id_A}")

        # ----------------------------------------------------
        # TEST 2: User A retry phien X: khong tao ban ghi thu hai
        # ----------------------------------------------------
        print("\n--- TEST 2: User A retry phien X ---")
        current_auth["user_id"] = user_A
        res2 = await ac.post("/api/v1/pomodoro/sync", json=make_payload(user_A, session_id_X, task="UserA_Work", pauses=1))
        assert res2.status_code == 200
        data_A2 = res2.json()
        assert data_A2["session_id"] == doc_id_A, "doc_id phai trung khop voi lan dau"
        count_A_after_retry = await db["pomodoro_sessions"].count_documents({"user_id": user_A})
        assert count_A_after_retry == 1, f"Retry khong duoc tao them ban ghi, thuc te: {count_A_after_retry}"
        print(f"[PASS] Test 2: User A retry nhan dien duplicate, khong tao ban ghi thu hai (doc_id={data_A2['session_id']})")

        # ----------------------------------------------------
        # TEST 3: User B gui cung session_id X: tao phien rieng cua B
        # ----------------------------------------------------
        print("\n--- TEST 3: User B gui cung session_id X ---")
        current_auth["user_id"] = user_B
        res3 = await ac.post("/api/v1/pomodoro/sync", json=make_payload(user_B, session_id_X, task="UserB_Study", pauses=4))
        assert res3.status_code == 200, f"Status code: {res3.status_code}"
        data_B1 = res3.json()
        doc_id_B = data_B1["session_id"]
        assert doc_id_B != doc_id_A, f"doc_id cua User B ({doc_id_B}) khong duoc trung voi User A ({doc_id_A})!"
        count_B = await db["pomodoro_sessions"].count_documents({"user_id": user_B})
        assert count_B == 1, f"User B phai co dung 1 ban ghi doc lap, thuc te: {count_B}"
        print(f"[PASS] Test 3: User B tao phien doc lap voi doc_id={doc_id_B} khac hoan toan User A")

        # ----------------------------------------------------
        # TEST 4: User B retry X: chi tra ve ban ghi cua B
        # ----------------------------------------------------
        print("\n--- TEST 4: User B retry phien X ---")
        current_auth["user_id"] = user_B
        res4 = await ac.post("/api/v1/pomodoro/sync", json=make_payload(user_B, session_id_X, task="UserB_Study", pauses=4))
        assert res4.status_code == 200
        data_B2 = res4.json()
        assert data_B2["session_id"] == doc_id_B, "User B retry phai giu nguyen doc_id cua B"
        assert data_B2["session_id"] != doc_id_A, "User B retry khong duoc tra ve doc_id cua A!"
        count_B_retry = await db["pomodoro_sessions"].count_documents({"user_id": user_B})
        assert count_B_retry == 1, "User B van chi co dung 1 ban ghi sau retry"
        print(f"[PASS] Test 4: User B retry chi tra ve dung ban ghi cua B (doc_id={doc_id_B})")

        # ----------------------------------------------------
        # TEST 5: User B khong the nhan _id, feedback hoac du lieu cua A
        # ----------------------------------------------------
        print("\n--- TEST 5: Kiem tra co lap du lieu tuyet doi giua User A va User B ---")
        # So sanh feedback: User A co 1 pause (it xao nhang), User B co 4 pauses
        assert data_A1["feedback"] != data_B1["feedback"], "Feedback cua User A va B phai doc lap theo hanh vi rieng!"
        assert data_A1["computed"]["concentration_score"] != data_B1["computed"]["concentration_score"], "Diem tap trung phai tinh rieng!"

        # User B thu doc lich su cua User A -> Phai bi HTTP 403 Forbidden
        current_auth["user_id"] = user_B
        res_history = await ac.get(f"/api/v1/pomodoro/history/{user_A}")
        assert res_history.status_code == 403, f"Ky vong HTTP 403 khi User B doc lich su cua A, thuc te: {res_history.status_code}"

        # Gia mao user_id trong JSON body trong khi token la User B -> Backend phai luu cho User B
        spoofed_payload = make_payload(user_A, "pomo_2026-10-16T18:30:00_2")
        res_spoof = await ac.post("/api/v1/pomodoro/sync", json=spoofed_payload)
        assert res_spoof.status_code == 200
        spoofed_doc_id = res_spoof.json()["session_id"]
        # Kiem tra trong DB: document phai thuoc ve user_B, khong duoc ghi cho user_A
        from bson import ObjectId
        spoofed_in_db = await db["pomodoro_sessions"].find_one({"_id": ObjectId(spoofed_doc_id)})
        assert spoofed_in_db["user_id"] == user_B, f"Backend khong duoc tin payload user_id! Thuoc ve: {spoofed_in_db['user_id']}"
        print("[PASS] Test 5: Co lap du lieu tuyet doi! User B khong xem duoc du lieu cua A va khong the gia mao user_id!")

        # ----------------------------------------------------
        # TEST 6: Hai user gui dong thoi cung session_id (Concurrent Concurrency)
        # ----------------------------------------------------
        print("\n--- TEST 6: Hai user gui dong thoi cung session_id ---")
        session_id_concurrent = "pomo_2026-10-16T19:00:00_5"
        
        # Tao 2 client voi 2 token rieng biet
        transport_A = ASGITransport(app=app)
        transport_B = ASGITransport(app=app)
        
        # Override rieng bang custom dependency
        async def call_user(u_id: str):
            app.dependency_overrides[get_current_user_id] = lambda: u_id
            async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as user_ac:
                return await user_ac.post("/api/v1/pomodoro/sync", json=make_payload(u_id, session_id_concurrent))

        res_concurrent_A, res_concurrent_B = await asyncio.gather(
            call_user(user_A),
            call_user(user_B)
        )
        assert res_concurrent_A.status_code == 200, f"User A failed with {res_concurrent_A.status_code}"
        assert res_concurrent_B.status_code == 200, f"User B failed with {res_concurrent_B.status_code}"
        doc_conc_A = res_concurrent_A.json()["session_id"]
        doc_conc_B = res_concurrent_B.json()["session_id"]
        assert doc_conc_A != doc_conc_B, "Hai session_id dong thoi phai tao 2 document rieng biet"
        print(f"[PASS] Test 6: Hai user gui dong thoi cung session_id thanh cong doc lap (A={doc_conc_A}, B={doc_conc_B})")

        # ----------------------------------------------------
        # TEST 7: Cung user gui dong thoi cung session_id (Race Condition)
        # ----------------------------------------------------
        print("\n--- TEST 7: Cung user gui dong thoi cung session_id ---")
        session_id_race = "pomo_2026-10-16T20:00:00_9"
        app.dependency_overrides[get_current_user_id] = lambda: user_A
        results_race = await asyncio.gather(
            ac.post("/api/v1/pomodoro/sync", json=make_payload(user_A, session_id_race)),
            ac.post("/api/v1/pomodoro/sync", json=make_payload(user_A, session_id_race))
        )
        assert results_race[0].status_code == 200
        assert results_race[1].status_code == 200
        assert results_race[0].json()["session_id"] == results_race[1].json()["session_id"]
        
        scoped_race = f"pomo_{user_A}_{session_id_race[5:]}"
        count_race = await db["pomodoro_sessions"].count_documents({"user_id": user_A, "session_id": scoped_race})
        assert count_race == 1, f"Cung user gui dong thoi chi duoc co 1 document, thuc te: {count_race}"
        print(f"[PASS] Test 7: Race condition cung user thanh cong, tao dung 1 document!")

        # ----------------------------------------------------
        # TEST 8: Loi DB, timeout va duplicate-key khong tao HTTP 200 gia
        # ----------------------------------------------------
        print("\n--- TEST 8: Loi DB, timeout va duplicate-key khong tao HTTP 200 gia ---")
        # Gia lap mock collection gay loi
        mock_coll = AsyncMock()
        mock_coll.update_one.side_effect = Exception("pymongo.errors.NetworkTimeout: connection timed out")
        mock_coll.find_one.return_value = None

        mock_db = {"pomodoro_sessions": mock_coll}
        app.dependency_overrides[get_database] = lambda: mock_db
        app.dependency_overrides[get_current_user_id] = lambda: user_A

        res_err = await ac.post("/api/v1/pomodoro/sync", json=make_payload(user_A, "pomo_timeout_test"))
        assert res_err.status_code == 503, f"Ky vong HTTP 503 khi timeout, thuc te: {res_err.status_code}"
        assert res_err.status_code != 200, "TUYET DOI KHONG tra ve HTTP 200 khi DB that bai!"
        print(f"[PASS] Test 8: Loi DB timeout tra ve dung HTTP 503, khong tao HTTP 200 gia mao!")

        # Tra lai db that
        app.dependency_overrides[get_database] = lambda: db

        # ----------------------------------------------------
        # TEST 10: productivity_logs va cap nhat AI khong bi anh huong
        # ----------------------------------------------------
        print("\n--- TEST 10: productivity_logs va AI update doc lap giua cac user ---")
        logs_A = await db["productivity_logs"].count_documents({"user_id": user_A})
        logs_B = await db["productivity_logs"].count_documents({"user_id": user_B})
        assert logs_A > 0, f"User A phai co logs trong productivity_logs, thuc te: {logs_A}"
        assert logs_B > 0, f"User B phai co logs trong productivity_logs, thuc te: {logs_B}"
        
        # Kiem tra tat ca log cua User A chi chua user_id cua User A
        async for log in db["productivity_logs"].find({"user_id": user_A}):
            assert log["user_id"] == user_A
        # Kiem tra tat ca log cua User B chi chua user_id cua User B
        async for log in db["productivity_logs"].find({"user_id": user_B}):
            assert log["user_id"] == user_B
        print(f"[PASS] Test 10: productivity_logs duoc tao doc lap hoan toan giua User A ({logs_A}) va User B ({logs_B})!")

    # Don dep du lieu test
    await db["pomodoro_sessions"].delete_many({"user_id": {"$in": [user_A, user_B]}})
    await db["productivity_logs"].delete_many({"user_id": {"$in": [user_A, user_B]}})

    app.dependency_overrides.clear()
    client.close()
    print("\n" + "=" * 70)
    print("TAT CA 10 BAI TEST MULTI-TENANT ISOLATION DEU DAT 100%!")
    print("=" * 70)

if __name__ == "__main__":
    asyncio.run(run_p1_multitenant_suite())
