"""
seed_burnout_data.py - Tạo dữ liệu burnout test cho một user cụ thể.
Dữ liệu được thiết kế để trigger các chỉ số burnout ở mức HIGH/CRITICAL.
"""
import asyncio
import httpx
from datetime import datetime, timedelta
import random

BASE_URL = "http://localhost:8000"
EMAIL = "Test2@gmail.com"
PASSWORD = "123456"

async def main():
    async with httpx.AsyncClient(timeout=30) as client:
        # 1. Login để lấy token và user_id
        print(f"[1] Đang đăng nhập {EMAIL}...")
        login_resp = await client.post(
            f"{BASE_URL}/api/v1/auth/login",
            json={"email": EMAIL, "password": PASSWORD}
        )
        if login_resp.status_code != 200:
            print(f"[LỖI] Login thất bại: {login_resp.text}")
            return

        login_data = login_resp.json()
        token = login_data.get("access_token")
        user_id = login_data.get("user_id") or login_data.get("id")

        # Thử lấy user_id từ /me nếu không có trong login response
        if not user_id:
            me_resp = await client.get(
                f"{BASE_URL}/api/v1/auth/me",
                headers={"Authorization": f"Bearer {token}"}
            )
            if me_resp.status_code == 200:
                user_id = me_resp.json().get("id") or me_resp.json().get("user_id")

        print(f"[OK] Đăng nhập thành công. user_id = {user_id}")

    # 2. Kết nối MongoDB trực tiếp để insert dữ liệu (nhanh hơn gọi API)
    from motor.motor_asyncio import AsyncIOMotorClient
    from dotenv import load_dotenv
    import os

    load_dotenv()
    mongo_uri = os.getenv("MONGO_URI", "mongodb://localhost:27017")
    db_name = os.getenv("DATABASE_NAME", "Pomodoro_App")

    mongo_client = AsyncIOMotorClient(mongo_uri)
    db = mongo_client[db_name]

    print(f"\n[2] Xóa dữ liệu productivity_logs cũ của user này (7 ngày)...")
    now = datetime.utcnow()
    cutoff = (now - timedelta(days=8)).isoformat()
    del_result = await db["productivity_logs"].delete_many({
        "user_id": user_id,
        "timestamp": {"$gte": cutoff}
    })
    print(f"    → Đã xóa {del_result.deleted_count} bản ghi cũ.")

    print(f"\n[3] Tạo dữ liệu Burnout CRITICAL (7 ngày qua)...")

    logs = []
    task_types = ["coding", "coding", "reading", "meeting", "coding", "general", "reading"]

    for day_offset in range(7):
        session_date = now - timedelta(days=day_offset)

        # Mỗi ngày 8-12 phiên (làm việc quá nhiều)
        num_sessions = random.randint(8, 12)

        for session_idx in range(num_sessions):
            hour = random.randint(8, 23)  # Làm đến tận đêm
            session_time = session_date.replace(
                hour=hour, minute=random.randint(0, 59),
                second=0, microsecond=0
            )

            # Điểm tập trung giảm dần theo ngày (burnout đang hình thành)
            base_score = max(15, 75 - (day_offset * 8) - (session_idx * 2))
            concentration_score = base_score + random.uniform(-5, 5)
            concentration_score = max(10, min(85, concentration_score))

            # Tỉ lệ bỏ break cao (>50%) → trigger burnout indicator
            break_skipped = random.random() < 0.65

            # Tỉ lệ hoàn thành thấp (<50%) → trigger burnout indicator
            completed = random.random() < 0.4
            completion_rate = 100.0 if completed else random.uniform(20, 75)

            # Nhiều lần bị ngắt (>3 lần/phiên)
            interruptions = random.randint(2, 7)

            log = {
                "user_id": user_id,
                "session_id": f"burnout_seed_{day_offset}_{session_idx}",
                "recommendation_id": None,
                "work_min": 25,
                "break_min": 5,
                "concentration_score": round(concentration_score, 1),
                "completion_rate": round(completion_rate, 1),
                "interruptions": interruptions,
                "break_skipped": break_skipped,
                "task_type": random.choice(task_types),
                "completed": completed,
                "timestamp": session_time.isoformat(),
                "hour_of_day": hour,
                "day_of_week": session_time.weekday(),
            }
            logs.append(log)

    # Insert tất cả
    insert_result = await db["productivity_logs"].insert_many(logs)
    print(f"    → Đã tạo {len(insert_result.inserted_ids)} phiên làm việc.")

    # Tóm tắt dữ liệu
    total_sessions = len(logs)
    avg_score = sum(l["concentration_score"] for l in logs) / total_sessions
    skip_rate = sum(1 for l in logs if l["break_skipped"]) / total_sessions
    completed_rate = sum(1 for l in logs if l["completed"]) / total_sessions
    avg_sessions_per_day = total_sessions / 7
    total_work_min = sum(l["work_min"] for l in logs)
    avg_daily_min = total_work_min / 7

    print(f"\n{'='*55}")
    print(f"📊 TÓM TẮT DỮ LIỆU BURNOUT TEST:")
    print(f"   • Tổng phiên: {total_sessions} ({avg_sessions_per_day:.1f} phiên/ngày)")
    print(f"   • Giờ làm TB/ngày: {avg_daily_min/60:.1f} giờ {'⚠️ (>8h)' if avg_daily_min > 480 else ''}")
    print(f"   • Điểm tập trung TB: {avg_score:.1f}/100")
    print(f"   • Tỉ lệ bỏ break: {skip_rate*100:.0f}% {'⚠️ (>40%)' if skip_rate > 0.4 else ''}")
    print(f"   • Tỉ lệ hoàn thành: {completed_rate*100:.0f}% {'⚠️ (<50%)' if completed_rate < 0.5 else ''}")
    print(f"{'='*55}")
    print(f"\n✅ Hoàn tất! Giờ gọi API /burnout/risk sẽ ra mức HIGH hoặc CRITICAL.")

    mongo_client.close()

if __name__ == "__main__":
    asyncio.run(main())
