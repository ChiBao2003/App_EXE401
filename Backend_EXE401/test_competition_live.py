"""Live two-user arena smoke test against a running local backend and MongoDB.

Run: python test_competition_live.py
Only documents created by this test are removed in finally.
"""

from datetime import datetime, timedelta, timezone
import os
import uuid

import requests
from pymongo import MongoClient


BASE = os.getenv("COMPETITION_TEST_URL", "http://127.0.0.1:8000")
MONGO_URI = os.getenv("MONGO_URI", "mongodb://localhost:27017")
DATABASE_NAME = os.getenv("MONGO_DB_NAME", "Pomodoro_App")


def call(method, path, token=None, expected=200, **kwargs):
    headers = {"Authorization": f"Bearer {token}"} if token else {}
    response = requests.request(
        method, f"{BASE}{path}", headers=headers, timeout=20, **kwargs
    )
    assert response.status_code == expected, (
        f"{method} {path}: expected {expected}, got {response.status_code}: "
        f"{response.text[:300]}"
    )
    return response.json()


def main():
    suffix = uuid.uuid4().hex[:12]
    db = MongoClient(MONGO_URI, serverSelectionTimeoutMS=5000)[DATABASE_NAME]
    user_ids = []
    room_code = None
    try:
        accounts = []
        for name in ("An", "Binh", "Ngoai phong", "Tu choi"):
            account = call(
                "POST", "/api/v1/auth/register", expected=201,
                json={
                    "email": f"arena_{name.replace(' ', '_')}_{suffix}@example.test",
                    "password": f"Test_{suffix}",
                    "display_name": name,
                },
            )
            accounts.append(account)
            user_ids.append(account["user"]["id"])
        a, b, outsider, declined = accounts
        token_a, token_b, token_outside, token_declined = (
            account["access_token"] for account in accounts
        )

        room = call(
            "POST", "/api/v1/competition/groups", token_a,
            json={"name": f"Arena {suffix}", "duration_days": 7},
        )
        room_code = room["room_code"]
        call(
            "POST", "/api/v1/competition/groups/join", token_b,
            json={"room_code": room_code},
        )
        leaderboard_path = f"/api/v1/competition/leaderboard/{room_code}"
        messages_path = f"/api/v1/competition/groups/{room_code}/messages"

        board = call("GET", leaderboard_path, token_a)
        assert {item["display_name"] for item in board["leaderboard"]} == {"An", "Binh"}
        assert all(item["score"] == 0 for item in board["leaderboard"])
        call("GET", leaderboard_path, token_outside, expected=403)
        call("GET", messages_path, token_outside, expected=403)
        call("POST", messages_path, token_outside, expected=403,
             json={"text": "Xam nhap"})

        call("POST", messages_path, token_a, expected=201,
             json={"text": "Chao Binh!"})
        unread_path = f"/api/v1/competition/groups/{room_code}/unread-status"
        assert call("GET", unread_path, token_b)["unread_count"] == 1
        assert call("GET", unread_path, token_a)["unread_count"] == 0
        call("GET", unread_path, token_outside, expected=403)
        call("POST", messages_path, token_b, expected=201,
             json={"text": "Chao An!"})
        messages_a = call("GET", messages_path, token_a)["messages"]
        messages_b = call("GET", messages_path, token_b)["messages"]
        assert call("GET", unread_path, token_a)["unread_count"] == 0
        assert call("GET", unread_path, token_b)["unread_count"] == 0
        call("POST", messages_path, token_a, expected=201, json={"text": "Tin 1"})
        call("POST", messages_path, token_a, expected=201, json={"text": "Tin 2"})
        assert call("GET", unread_path, token_b)["unread_count"] == 2
        call("GET", messages_path, token_b)
        assert call("GET", unread_path, token_b)["unread_count"] == 0
        assert [item["text"] for item in messages_a] == ["Chao Binh!", "Chao An!"]
        assert messages_a == messages_b
        assert [item["sender_name"] for item in messages_a] == ["An", "Binh"]
        call("POST", messages_path, token_a, expected=422,
             json={"text": "   "})
        call("POST", "/api/v1/competition/groups/messages", token_b, expected=201,
             json={"room_code": room_code, "text": "Dung endpoint moi"})

        call("POST", "/api/v1/competition/friends/add", token_a,
             json={"receiver_id": b["user"]["id"]})
        assert call("GET", "/api/v1/competition/friends/unread-status", token_b)["pending_requests"] == 1
        call("POST", "/api/v1/competition/friends/messages", token_a, expected=403,
             json={"receiver_id": b["user"]["id"], "text": "Too early"})
        call("POST", "/api/v1/competition/friends/respond", token_b,
             json={"requester_id": a["user"]["id"], "action": "accept"})
        friends = call("GET", f"/api/v1/competition/friends/{a['user']['id']}", token_a)
        assert friends["friends"][0]["display_name"] == "Binh"
        call("GET", f"/api/v1/competition/friends/{a['user']['id']}", token_outside,
             expected=403)
        call("POST", "/api/v1/competition/friends/messages", token_a, expected=201,
             json={"receiver_id": b["user"]["id"], "text": "Tin rieng"})
        assert call("GET", "/api/v1/competition/friends/unread-status", token_b)["unread_messages"] == 1
        direct = call("GET", "/api/v1/competition/friends/messages",
                      token_b, params={"friend_id": a["user"]["id"]})
        assert direct["messages"][0]["text"] == "Tin rieng"
        assert call("GET", "/api/v1/competition/friends/unread-status", token_b)["unread_messages"] == 0
        call("GET", "/api/v1/competition/friends/unread-status", token_b,
             expected=403, params={"user_id": a["user"]["id"]})
        call("GET", "/api/v1/competition/friends/messages", token_b,
             expected=403, params={"friend_id": a["user"]["id"],
                                   "user_id": a["user"]["id"]})
        call("GET", "/api/v1/competition/friends/messages", token_outside,
             expected=403, params={"friend_id": a["user"]["id"]})
        call("POST", "/api/v1/competition/friends/add", token_outside,
             json={"receiver_id": a["user"]["id"]})
        reverse = call("POST", "/api/v1/competition/friends/add", token_a,
                       json={"receiver_id": outsider["user"]["id"]})
        assert reverse["status"] == "accepted"
        call("POST", "/api/v1/competition/friends/add", token_declined,
             json={"receiver_id": a["user"]["id"]})
        call("POST", "/api/v1/competition/friends/respond", token_a,
             json={"requester_id": declined["user"]["id"], "action": "decline"})
        assert not call("GET", f"/api/v1/competition/friends/{a['user']['id']}",
                        token_a)["incoming_requests"]
        new_name = f"An {suffix}"
        call("POST", "/api/v1/competition/nickname/update", token_a,
             json={"nickname": new_name})
        call("POST", "/api/v1/competition/nickname/update", token_b,
             expected=409, json={"nickname": new_name})
        call("POST", "/api/v1/auth/register", expected=409, json={
            "email": f"duplicate_{suffix}@example.test", "password": f"Test_{suffix}",
            "display_name": new_name,
        })

        call("POST", "/api/v1/competition/submit", token_b,
             json={"work_min": 10, "completed": True, "pauses": 0})
        room_messages = call("GET", f"/api/v1/competition/groups/messages/{room_code}", token_a)["messages"]
        assert any(msg["user_id"] == "system" and "+25" in msg["text"] for msg in room_messages)
        now = datetime.now(timezone.utc)
        sync_payload = {
            "user_id": b["user"]["id"],  # spoofing must not award B
            "session_id": f"arena_{suffix}",
            "hardware_data": {
                "work_min": 25, "break_min": 5, "pauses": 0,
                "completed": True, "session_count": 1,
                "start_time": (now - timedelta(minutes=25)).replace(tzinfo=None).isoformat(),
                "end_time": now.replace(tzinfo=None).isoformat(),
            },
            "phone_data": {"unlock_count": 0, "task_type": "general"},
        }
        call("POST", "/api/v1/pomodoro/sync", token_a, json=sync_payload)
        call("POST", "/api/v1/pomodoro/sync", token_a, json=sync_payload)
        board = call("GET", leaderboard_path + "?period=today", token_b)
        by_name = {item["display_name"]: item for item in board["leaderboard"]}
        assert by_name[new_name]["score"] == 40, by_name
        assert by_name["Binh"]["score"] == 25, by_name
        assert board["leaderboard"][0]["display_name"] == new_name
        db["pomodoro_sessions"].delete_many({"user_id": a["user"]["id"],
                                             "hardware_session_id": f"arena_{suffix}"})
        retained = call("GET", leaderboard_path + "?period=all", token_a)
        assert next(item for item in retained["leaderboard"] if item["user_id"] == a["user"]["id"])["score"] == 40
        summary = call("GET", "/api/v1/competition/stats/summary?period=today", token_a)
        assert summary["minutes"] >= 25 and len(summary["last_7_days"]) == 7
        call("GET", "/api/v1/competition/stats/summary?period=today", token_outside,
             expected=403, params={"user_id": a["user"]["id"]})
        print("PASS: room, unread badge counts, two-way chat, system message, friendships, direct chat,")
        print("      nickname, summary, access control, scoring and sync idempotency")
    finally:
        if room_code:
            db["Groups"].delete_many({"room_code": room_code})
            db["CompetitionMessages"].delete_many({"room_code": room_code})
            db["RoomMessages"].delete_many({"room_code": room_code})
            db["RoomReadStates"].delete_many({"room_code": room_code})
            db["Friendships"].delete_many({"$or": [
                {"requester_id": {"$in": user_ids}},
                {"receiver_id": {"$in": user_ids}},
            ]})
            db["DirectMessages"].delete_many({"$or": [
                {"sender_id": {"$in": user_ids}},
                {"receiver_id": {"$in": user_ids}},
            ]})
        if user_ids:
            db["DailyStats"].delete_many({"user_id": {"$in": user_ids}})
            db["pomodoro_sessions"].delete_many({"user_id": {"$in": user_ids}})
            db["CompetitionSessionScores"].delete_many({"user_id": {"$in": user_ids}})
            db["productivity_logs"].delete_many({"user_id": {"$in": user_ids}})
            db["users"].delete_many({"_id": {"$in": user_ids}})


if __name__ == "__main__":
    main()
