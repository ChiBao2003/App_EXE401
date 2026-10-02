import asyncio
import datetime
from pymongo import MongoClient

def reset_and_seed_productivity():
    print("Đang kết nối tới MongoDB...")
    client = MongoClient("mongodb://localhost:27017/")
    db = client["Pomodoro_App"]
    
    # 1. Xóa toàn bộ rác test cũ gây lỗi Burnout
    collections_to_drop = [
        "productivity_logs", 
        "ai_recommendation_logs", 
        "ai_chat_history", 
        "ai_work_schedules"
    ]
    
    for coll in collections_to_drop:
        db[coll].delete_many({})
        print(f"🗑️ Đã xóa sạch collection: {coll}")

    # 2. Tạo bộ data test "Khỏe mạnh & Năng suất cao"
    # Giả lập data cho 7 ngày qua
    print("🌱 Đang sinh dữ liệu mẫu (Mock Data)...")
    user_id = "test_user_id" # Mặc định hoặc id test bạn đang dùng
    
    # Do frontend không gửi kèm user_id cụ thể hoặc dùng default 'anonymous'/'test_user_id'
    # Ở đây chèn cho cả 'anonymous' và 'test_user_id' để chắc chắn match
    
    logs = []
    now = datetime.datetime.utcnow()
    
    import random
    
    # Sinh dữ liệu 7 ngày, mỗi ngày 3-4 phiên (không quá 8 phiên để tránh Burnout)
    for day_offset in range(7, -1, -1):
        date_str = (now - datetime.timedelta(days=day_offset)).strftime("%Y-%m-%d")
        
        # Buổi sáng: 2 phiên
        for hour in [9, 10]:
            logs.append({
                "user_id": "anonymous", # Tên mặc định của App nếu chưa đăng nhập
                "session_id": f"sess_{date_str}_{hour}",
                "work_min": 30,
                "break_min": 5,
                "concentration_score": random.randint(75, 95), # Focus cao buổi sáng
                "completion_rate": 100,
                "interruptions": random.randint(0, 1),
                "break_skipped": False,
                "task_type": "coding",
                "completed": True,
                "timestamp": f"{date_str}T{hour:02d}:00:00Z",
                "hour_of_day": hour,
                "day_of_week": (now - datetime.timedelta(days=day_offset)).weekday()
            })
            
        # Buổi chiều: 2 phiên
        for hour in [14, 15]:
            logs.append({
                "user_id": "anonymous",
                "session_id": f"sess_{date_str}_{hour}",
                "work_min": 25,
                "break_min": 10,
                "concentration_score": random.randint(60, 80), # Focus trung bình buổi chiều
                "completion_rate": random.choice([80, 100]),
                "interruptions": random.randint(0, 2),
                "break_skipped": False,
                "task_type": "reading",
                "completed": True,
                "timestamp": f"{date_str}T{hour:02d}:00:00Z",
                "hour_of_day": hour,
                "day_of_week": (now - datetime.timedelta(days=day_offset)).weekday()
            })

    # Nhân bản data cho "test_user_id" phòng hờ
    logs_copy = []
    for log in logs:
        new_log = log.copy()
        new_log["user_id"] = "test_user_id"
        logs_copy.append(new_log)
        
    db["productivity_logs"].insert_many(logs + logs_copy)
    print(f"✅ Đã tạo thành công {len(logs)} bản ghi Pomodoro chất lượng cao!")
    print("Bây giờ bạn có thể chat lại với AI, nó sẽ khen bạn và lên lịch rất thông minh!")

if __name__ == "__main__":
    reset_and_seed_productivity()
