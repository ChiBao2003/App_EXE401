"""
test_backend_multitenant_full.py - Verify multi-tenant isolation across all updated routers:
- usage_router.py (/usage/distractions, /usage/ai-context)
- competition_router.py (/competition/groups, /competition/groups/join, /competition/submit, /competition/leaderboard)
- schedule_router.py (/schedules GET, POST, DELETE)
"""
import sys
import os
import asyncio
import datetime
from bson import ObjectId
from httpx import AsyncClient, ASGITransport
from motor.motor_asyncio import AsyncIOMotorClient

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from main import app
from core.database import connect_db, close_db, get_database, MONGO_URI, DATABASE_NAME
from core.security import get_current_user_id


async def run_all_tests():
    print("=" * 70)
    print("BAT DAU KIEM THU TOAN DIEN MULTI-TENANT MOI CAP NHAT")
    print("=" * 70)

    await connect_db()
    db = get_database()
    app.database = db

    user_alice = "test_mt_alice"
    user_bob = "test_mt_bob"
    user_eve = "test_mt_eve"
    session_id_1 = "pomo_2026-10-16T19:00:00_test"

    # Cleanup test data
    await db["usage_events"].delete_many({"user_id": {"$in": [user_alice, user_bob, user_eve]}})
    await db["daily_summaries"].delete_many({"user_id": {"$in": [user_alice, user_bob, user_eve]}})
    await db["Groups"].delete_many({"created_by": {"$in": [user_alice, user_bob, user_eve]}})
    await db["DailyStats"].delete_many({"user_id": {"$in": [user_alice, user_bob, user_eve]}})
    await db["schedules"].delete_many({"user_id": {"$in": [user_alice, user_bob, user_eve]}})

    current_auth = {"user_id": user_alice}
    app.dependency_overrides[get_current_user_id] = lambda: current_auth["user_id"]

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as http_client:
        print("\n--- TEST 1: Usage Router Multi-Tenant (/distractions & /ai-context) ---")
        # Seed distractions for Alice and Bob with same session_id
        await db["usage_events"].insert_many([
            {"user_id": user_alice, "pomodoro_session_id": session_id_1, "event_type": "distraction", "timestamp": "2026-10-16T10:00:00Z", "app_name": "Facebook"},
            {"user_id": user_bob, "pomodoro_session_id": session_id_1, "event_type": "distraction", "timestamp": "2026-10-16T10:05:00Z", "app_name": "TikTok"},
        ])
        today_str = datetime.datetime.utcnow().strftime("%Y-%m-%d")
        await db["daily_summaries"].insert_many([
            {"user_id": user_alice, "date": today_str, "total_screen_time_ms": 3600000, "total_unlocks": 10, "focus_score": 85},
            {"user_id": user_bob, "date": today_str, "total_screen_time_ms": 7200000, "total_unlocks": 50, "focus_score": 40},
        ])

        # Alice requests distractions for session_id_1
        current_auth["user_id"] = user_alice
        r = await http_client.get(f"/api/v1/usage/distractions?session_id={session_id_1}")
        assert r.status_code == 200, f"Expected 200, got {r.status_code}"
        data = r.json()
        assert len(data["distractions"]) == 1
        assert data["distractions"][0]["user_id"] == user_alice
        print("[PASS] Alice chi nhan duoc su kien mat tap trung cua chinh minh.")

        # Bob requests distractions for session_id_1
        current_auth["user_id"] = user_bob
        r = await http_client.get(f"/api/v1/usage/distractions?session_id={session_id_1}")
        assert r.status_code == 200
        data = r.json()
        assert len(data["distractions"]) == 1
        assert data["distractions"][0]["user_id"] == user_bob
        print("[PASS] Bob chi nhan duoc su kien mat tap trung cua chinh minh.")

        # Alice requests ai-context
        current_auth["user_id"] = user_alice
        r = await http_client.get(f"/api/v1/usage/ai-context?date={today_str}")
        assert r.status_code == 200
        data = r.json()
        assert data["has_data"] is True
        assert data["summary"]["unlocks"] == 10
        print("[PASS] Alice nhan dung context AI cua minh (unlocks=10).")

        # Bob requests ai-context
        current_auth["user_id"] = user_bob
        r = await http_client.get(f"/api/v1/usage/ai-context?date={today_str}")
        assert r.status_code == 200
        data = r.json()
        assert data["has_data"] is True
        assert data["summary"]["unlocks"] == 50
        print("[PASS] Bob nhan dung context AI cua minh (unlocks=50).")

        print("\n--- TEST 2: Competition Router Multi-Tenant & Anti-Spoofing ---")
        # Alice creates group
        current_auth["user_id"] = user_alice
        r = await http_client.post("/api/v1/competition/groups", json={"name": "Alice Study Group", "duration_days": 7})
        assert r.status_code == 200
        room_code = r.json()["room_code"]
        assert room_code is not None
        group_doc = await db["Groups"].find_one({"room_code": room_code})
        assert user_alice in group_doc["members"]
        print(f"[PASS] Tao phong '{room_code}' thanh cong, Alice tu dong la member.")

        # Bob tries to access leaderboard before joining -> 403 Forbidden
        current_auth["user_id"] = user_bob
        r = await http_client.get(f"/api/v1/competition/leaderboard/{room_code}")
        assert r.status_code == 403, f"Expected 403 Forbidden for non-member, got {r.status_code}"
        print("[PASS] Bob (chua vao phong) bi chan 403 Forbidden khi xem BXH.")

        # Bob joins group
        r = await http_client.post("/api/v1/competition/groups/join", json={"room_code": room_code})
        assert r.status_code == 200
        group_doc = await db["Groups"].find_one({"room_code": room_code})
        assert user_bob in group_doc["members"]
        print("[PASS] Bob tham gia phong thanh cong, cap nhat group.members.")

        # Bob accesses leaderboard after joining -> 200 OK
        r = await http_client.get(f"/api/v1/competition/leaderboard/{room_code}")
        assert r.status_code == 200
        print("[PASS] Bob (thanh vien) xem BXH thanh cong voi HTTP 200.")

        # Eve (outsider) tries to access leaderboard -> 403 Forbidden
        current_auth["user_id"] = user_eve
        r = await http_client.get(f"/api/v1/competition/leaderboard/{room_code}")
        assert r.status_code == 403
        print("[PASS] Eve (nguoi ngoai) bi chan 403 Forbidden khi xem BXH.")

        # Anti-spoofing in /competition/submit: Eve tries to submit score with user_id = Alice
        r = await http_client.post("/api/v1/competition/submit", json={
            "user_id": user_alice,  # Spoofed user_id in body
            "work_min": 25,
            "completed": True,
            "pauses": 0
        })
        assert r.status_code == 200
        eve_stats = await db["DailyStats"].find_one({"user_id": user_eve, "date": today_str})
        alice_stats = await db["DailyStats"].find_one({"user_id": user_alice, "date": today_str})
        assert eve_stats is not None, "Diem phai duoc cong cho caller (Eve)"
        assert eve_stats["total_score"] == 40  # 25 + 15
        assert alice_stats is None, "Alice khong duoc bi cong diem gia mao tu Eve"
        print("[PASS] Chong mao danh thanh cong: Diem duoc ghi vao Eve theo JWT token, khong the sua diem cua Alice!")

        print("\n--- TEST 3: Schedule Router Multi-Tenant Isolation ---")
        # Alice creates a schedule
        current_auth["user_id"] = user_alice
        r = await http_client.post("/api/v1/schedules/", json={
            "day_of_week": "Mon",
            "hour": 8,
            "minute": 30,
            "label": "Alice Math Class"
        })
        assert r.status_code == 200
        alice_sched_id = r.json()["inserted_id"]
        assert alice_sched_id is not None

        # Bob creates a schedule
        current_auth["user_id"] = user_bob
        r = await http_client.post("/api/v1/schedules/", json={
            "day_of_week": "Tue",
            "hour": 14,
            "minute": 0,
            "label": "Bob Physics Lab"
        })
        assert r.status_code == 200
        bob_sched_id = r.json()["inserted_id"]

        # Alice lists schedules -> only sees her own
        current_auth["user_id"] = user_alice
        r = await http_client.get("/api/v1/schedules/")
        assert r.status_code == 200
        schedules = r.json()
        assert len(schedules) == 1
        assert schedules[0]["label"] == "Alice Math Class"
        assert schedules[0]["_id"] == alice_sched_id
        print("[PASS] Alice chi xem duoc lich cua chinh minh.")

        # Bob lists schedules -> only sees his own
        current_auth["user_id"] = user_bob
        r = await http_client.get("/api/v1/schedules/")
        assert r.status_code == 200
        schedules = r.json()
        assert len(schedules) == 1
        assert schedules[0]["label"] == "Bob Physics Lab"
        assert schedules[0]["_id"] == bob_sched_id
        print("[PASS] Bob chi xem duoc lich cua chinh minh.")

        # Bob tries to delete Alice's schedule -> failure
        r = await http_client.delete(f"/api/v1/schedules/{alice_sched_id}")
        assert r.status_code == 200
        assert r.json()["success"] is False
        doc = await db["schedules"].find_one({"_id": ObjectId(alice_sched_id)})
        assert doc is not None, "Lich cua Alice phai con nguyen trong DB"
        print("[PASS] Bob khong the xoa lich cua Alice.")

        # Alice deletes her own schedule -> success
        current_auth["user_id"] = user_alice
        r = await http_client.delete(f"/api/v1/schedules/{alice_sched_id}")
        assert r.status_code == 200
        assert r.json()["success"] is True
        doc = await db["schedules"].find_one({"_id": ObjectId(alice_sched_id)})
        assert doc is None
        print("[PASS] Alice xoa thanh cong lich cua chinh minh.")

    # Cleanup after test
    await db["usage_events"].delete_many({"user_id": {"$in": [user_alice, user_bob, user_eve]}})
    await db["daily_summaries"].delete_many({"user_id": {"$in": [user_alice, user_bob, user_eve]}})
    await db["Groups"].delete_many({"created_by": {"$in": [user_alice, user_bob, user_eve]}})
    await db["DailyStats"].delete_many({"user_id": {"$in": [user_alice, user_bob, user_eve]}})
    await db["schedules"].delete_many({"user_id": {"$in": [user_alice, user_bob, user_eve]}})

    print("\n" + "=" * 70)
    print("HOAN TAT! TAT CA CAC TEST MULTI-TENANT BACKEND MOI CAP NHAT DAT 100%!")
    print("=" * 70)

if __name__ == "__main__":
    asyncio.run(run_all_tests())
