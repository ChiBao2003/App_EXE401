# ==========================================
# THI_DUA_FEATURE_START (By Gemini)
# ==========================================
# Ghi chú: File này chứa toàn bộ logic cho tính năng Thi đua nhóm (Productivity Competition).
# Tính năng này hoạt động hoàn toàn độc lập với AI, sử dụng Rule-based logic.
# Các API bao gồm:
# - POST /api/v1/competition/groups : Tạo phòng thi đua mới
# - POST /api/v1/competition/groups/join : Xin vào phòng
# - POST /api/v1/competition/submit : Chốt sổ điểm 1 phiên Pomodoro (không dùng AI)
# - GET /api/v1/competition/leaderboard/{room_code}?period=today|week|month|all : Lấy bảng xếp hạng
# ==========================================

from fastapi import APIRouter, Request, HTTPException, Query
from pydantic import BaseModel
from typing import List, Optional
import datetime
import uuid

# ============================================================
# MÚI GIỜ THỰC TẾ VIỆT NAM (UTC+7 / ICT)
# ============================================================
VN_TZ = datetime.timezone(datetime.timedelta(hours=7))

def get_now() -> datetime.datetime:
    """Trả về thời gian hiện tại chuẩn xác theo giờ thực tế Việt Nam (UTC+7) dạng naive datetime"""
    return datetime.datetime.now(VN_TZ).replace(tzinfo=None)

def _format_msg_time(dt: Optional[datetime.datetime]) -> str:
    """
    Format thời gian tin nhắn theo giờ thực tế:
    - Nếu gửi hôm nay: '14:35'
    - Nếu gửi ngày khác: '14:35, 14/10'
    """
    if not dt or not isinstance(dt, datetime.datetime):
        return ""
    if dt.tzinfo is not None:
        local_dt = dt.astimezone(VN_TZ).replace(tzinfo=None)
    else:
        local_dt = dt

    now = get_now()
    if local_dt.date() == now.date():
        return local_dt.strftime("%H:%M")
    return local_dt.strftime("%H:%M, %d/%m")

router = APIRouter()

# --- Models ---
class GroupCreate(BaseModel):
    name: str
    duration_days: int # 7 (1 tuần), 30 (1 tháng)

class GroupJoin(BaseModel):
    room_code: str
    user_id: str

class PomodoroSubmission(BaseModel):
    user_id: str
    work_min: int
    completed: bool
    pauses: int

class RoomMessageCreate(BaseModel):
    sender_id: str
    message: str
    msg_type: str = "user" # user | system

class FriendAdd(BaseModel):
    user_id: str
    friend_id: str

class DirectMessageCreate(BaseModel):
    sender_id: str
    receiver_id: str
    message: str

# --- Rule-Based Scoring Logic ---
def calculate_prs(work_min: int, completed: bool, pauses: int) -> int:
    """
    Công thức: 
    - 1 phút tập trung = 1 điểm
    - Hoàn thành trọn vẹn (completed=True) = +15 điểm thưởng
    - Xao nhãng (mở khoá điện thoại / pauses) = -10 điểm mỗi lần
    """
    score = work_min
    if completed:
        score += 15
    score -= (pauses * 10)
    
    # Đảm bảo điểm không bị âm
    return max(0, score)

def generate_room_code():
    return str(uuid.uuid4())[:6].upper()

def _check_expired(group: dict) -> bool:
    """Kiểm tra phòng đã hết hạn chưa dựa trên created_at + duration_days"""
    created = group.get("created_at")
    duration = group.get("duration_days", 7)
    if not created:
        return False
    expiry = created + datetime.timedelta(days=duration)
    return get_now() > expiry

def _get_date_filter(period: str) -> Optional[str]:
    """Trả về ngày bắt đầu lọc dựa theo period (today/week/month) theo múi giờ VN"""
    now = get_now()
    if period == "today":
        return now.strftime("%Y-%m-%d")
    elif period == "week":
        start = now - datetime.timedelta(days=now.weekday())  # Thứ 2 tuần này (giờ VN)
        return start.strftime("%Y-%m-%d")
    elif period == "month":
        return now.strftime("%Y-%m-01")  # Ngày 1 tháng này (giờ VN)
    return None  # "all" => không lọc

# --- Endpoints ---
@router.post("/groups")
async def create_group(request: Request, payload: GroupCreate):
    db = request.app.database
    if db is None:
        raise HTTPException(status_code=500, detail="Database not connected")
    
    room_code = generate_room_code()
    group_doc = {
        "room_code": room_code,
        "name": payload.name,
        "duration_days": payload.duration_days,
        "members": [],
        "created_at": get_now()
    }
    
    await db["Groups"].insert_one(group_doc)
    return {
        "status": "success", 
        "room_code": room_code, 
        "message": f"Tao phong '{payload.name}' thanh cong! Ma phong: {room_code}"
    }

@router.post("/groups/join")
async def join_group(request: Request, payload: GroupJoin):
    db = request.app.database
    if db is None:
        raise HTTPException(status_code=500, detail="Database not connected")
    
    group = await db["Groups"].find_one({"room_code": payload.room_code})
    if not group:
        raise HTTPException(status_code=404, detail="Khong tim thay ma phong")
    
    # Kiểm tra phòng đã hết hạn chưa
    if _check_expired(group):
        raise HTTPException(status_code=400, detail="Phong da het han thi dua")
    
    # Kiểm tra giới hạn thành viên (tối đa 5 người để cạnh tranh tốt)
    if payload.user_id not in group["members"]:
        if len(group["members"]) >= 5:
            raise HTTPException(status_code=400, detail="Phong da day (Toi da 5 nguoi)")
            
        await db["Groups"].update_one(
            {"room_code": payload.room_code},
            {"$push": {"members": payload.user_id}}
        )
        
    return {"status": "success", "message": "Da tham gia phong thi dua thanh cong!"}

@router.post("/submit")
async def submit_session(request: Request, payload: PomodoroSubmission):
    db = request.app.database
    if db is None:
        raise HTTPException(status_code=500, detail="Database not connected")
    
    # 1. Tính toán điểm PRS theo logic cứng (không dùng AI)
    prs = calculate_prs(payload.work_min, payload.completed, payload.pauses)
    
    # 2. Lưu vào CSDL tổng hợp theo ngày (giờ Việt Nam thực tế)
    today = get_now().strftime("%Y-%m-%d")
    
    await db["DailyStats"].update_one(
        {"user_id": payload.user_id, "date": today},
        {
            "$inc": {
                "total_score": prs, 
                "total_work_min": payload.work_min,
                "completed_sessions": 1 if payload.completed else 0
            }
        },
        upsert=True
    )
    
    # 3. Thông báo hệ thống vào các phòng thi đua user đang tham gia
    try:
        user_rooms = await db["Groups"].find({"members": payload.user_id}).to_list(20)
        for rm in user_rooms:
            if not _check_expired(rm):
                await db["RoomMessages"].insert_one({
                    "room_code": rm["room_code"],
                    "sender_id": "Hệ Thống",
                    "message": f"🎉 {payload.user_id} vừa cày xong phiên {payload.work_min} phút (+{prs} điểm PRS)!",
                    "msg_type": "system",
                    "created_at": get_now()
                })
    except Exception:
        pass
    
    return {
        "status": "success", 
        "prs_earned": prs, 
        "message": f"Tuyet voi! Ban nhan duoc {prs} diem PRS."
    }

@router.get("/leaderboard/{room_code}")
async def get_leaderboard(
    request: Request, 
    room_code: str,
    period: str = Query(default="all", pattern="^(today|week|month|all)$")
):
    """
    Lấy bảng xếp hạng tổng điểm của phòng thi đua.
    Query param `period`: today | week | month | all
    """
    db = request.app.database
    if db is None:
        raise HTTPException(status_code=500, detail="Database not connected")
    
    group = await db["Groups"].find_one({"room_code": room_code})
    if not group:
        raise HTTPException(status_code=404, detail="Khong tim thay ma phong")
    
    # Kiểm tra hết hạn
    expired = _check_expired(group)
    
    members = group["members"]
    if not members:
        return {
            "room_code": room_code, 
            "group_name": group["name"],
            "duration_days": group["duration_days"],
            "expired": expired,
            "period": period,
            "leaderboard": []
        }
    
    # Xây dựng filter theo period
    match_filter = {"user_id": {"$in": members}}
    date_start = _get_date_filter(period)
    if date_start:
        match_filter["date"] = {"$gte": date_start}
        
    # Aggregate điểm từ DailyStats cho các thành viên trong nhóm
    pipeline = [
        {"$match": match_filter},
        {
            "$group": {
                "_id": "$user_id", 
                "total_score": {"$sum": "$total_score"}, 
                "total_work_min": {"$sum": "$total_work_min"},
                "total_completed": {"$sum": "$completed_sessions"}
            }
        },
        {"$sort": {"total_score": -1}} # Xếp hạng từ cao xuống thấp
    ]
    
    results = await db["DailyStats"].aggregate(pipeline).to_list(None)
    
    leaderboard = []
    for idx, r in enumerate(results):
        leaderboard.append({
            "rank": idx + 1,
            "user_id": r["_id"],
            "score": r["total_score"],
            "work_min": r["total_work_min"],
            "completed": r.get("total_completed", 0)
        })
        
    return {
        "room_code": room_code, 
        "group_name": group["name"],
        "duration_days": group["duration_days"],
        "expired": expired,
        "period": period,
        "leaderboard": leaderboard
    }

# ==========================================
# 1. API THỐNG KÊ NGOÀI SẢNH (1 NGÀY / 1 TUẦN / 1 THÁNG)
# ==========================================
@router.get("/stats/summary")
async def get_stats_summary(
    request: Request,
    user_id: str,
    period: str = Query(default="today", pattern="^(today|week|month)$")
):
    """
    Thống kê thi đua cá nhân ở ngoài sảnh: 1 ngày, 1 tuần, 1 tháng.
    Trả về dữ liệu giống smartwatch: tổng phút, điểm, phiên, xếp hạng,
    daily_breakdown (7 ngày gần nhất), avg_min_per_session, completion_rate,
    streak, best_streak, goal_progress.
    """
    db = request.app.database
    if db is None:
        raise HTTPException(status_code=500, detail="Database not connected")

    date_start = _get_date_filter(period)
    match_filter = {}
    if date_start:
        match_filter["date"] = {"$gte": date_start}

    # Bảng xếp hạng toàn hệ thống cho period này
    pipeline = [
        {"$match": match_filter} if match_filter else {"$match": {}},
        {
            "$group": {
                "_id": "$user_id",
                "total_score": {"$sum": "$total_score"},
                "total_work_min": {"$sum": "$total_work_min"},
                "total_completed": {"$sum": "$completed_sessions"}
            }
        },
        {"$sort": {"total_score": -1}}
    ]
    all_users = await db["DailyStats"].aggregate(pipeline).to_list(None)

    # Tìm thông tin của user_id
    user_score = 0
    user_work_min = 0
    user_completed = 0
    user_rank = 0
    for idx, u in enumerate(all_users):
        if u["_id"] == user_id:
            user_score = u["total_score"]
            user_work_min = u["total_work_min"]
            user_completed = u.get("total_completed", 0)
            user_rank = idx + 1
            break

    # --- Daily breakdown (7 ngày gần nhất) cho biểu đồ cột theo giờ VN ---
    now = get_now()
    daily_breakdown = []
    vn_day_names = {
        "Mon": "T2", "Tue": "T3", "Wed": "T4", "Thu": "T5", "Fri": "T6", "Sat": "T7", "Sun": "CN"
    }
    for i in range(6, -1, -1):
        day = now - datetime.timedelta(days=i)
        day_str = day.strftime("%Y-%m-%d")
        en_label = day.strftime("%a")
        vn_label = vn_day_names.get(en_label, en_label)
        doc = await db["DailyStats"].find_one({"user_id": user_id, "date": day_str})
        daily_breakdown.append({
            "date": day_str,
            "short_date": day.strftime("%d/%m"),
            "label": vn_label,
            "en_label": en_label,
            "is_today": (i == 0),
            "work_min": doc["total_work_min"] if doc else 0,
            "score": doc["total_score"] if doc else 0,
            "sessions": doc["completed_sessions"] if doc else 0,
        })

    # --- Tính avg, completion_rate, streak ---
    total_sessions_raw = user_completed
    avg_min_per_session = round(user_work_min / total_sessions_raw, 1) if total_sessions_raw > 0 else 0

    # Mục tiêu mặc định: 120 phút/ngày = 100%
    goal_min = 120
    if period == "week":
        goal_min = 120 * 7
    elif period == "month":
        goal_min = 120 * 30
    goal_progress = min(1.0, round(user_work_min / goal_min, 3)) if goal_min > 0 else 0

    # Completion rate: phiên hoàn thành / tổng số ngày có dữ liệu
    days_with_data = sum(1 for d in daily_breakdown if d["work_min"] > 0)
    completion_rate = round((days_with_data / 7) * 100) if days_with_data > 0 else 0

    # Streak: số ngày liên tục có hoạt động (tính ngược từ hôm nay theo giờ VN)
    streak = 0
    for i in range(7):
        day = now - datetime.timedelta(days=i)
        day_str = day.strftime("%Y-%m-%d")
        doc = await db["DailyStats"].find_one({"user_id": user_id, "date": day_str})
        if doc and doc.get("total_work_min", 0) > 0:
            streak += 1
        else:
            break

    user_data = {
        "user_id": user_id,
        "period": period,
        "total_score": user_score,
        "total_work_min": user_work_min,
        "completed_sessions": user_completed,
        "rank": user_rank,
        "total_users": len(all_users),
        # Smartwatch-style extra metrics
        "daily_breakdown": daily_breakdown,
        "avg_min_per_session": avg_min_per_session,
        "completion_rate": completion_rate,
        "streak": streak,
        "goal_progress": goal_progress,
        "goal_min": goal_min,
    }

    return user_data

@router.get("/stats/global-top")
async def get_global_top(
    request: Request,
    period: str = Query(default="today", pattern="^(today|week|month)$"),
    limit: int = 5
):
    """Lấy danh sách Top cao thủ thi đua toàn hệ thống theo 1 ngày, 1 tuần, 1 tháng"""
    db = request.app.database
    if db is None:
        raise HTTPException(status_code=500, detail="Database not connected")

    date_start = _get_date_filter(period)
    match_filter = {}
    if date_start:
        match_filter["date"] = {"$gte": date_start}

    pipeline = [
        {"$match": match_filter} if match_filter else {"$match": {}},
        {
            "$group": {
                "_id": "$user_id",
                "total_score": {"$sum": "$total_score"},
                "total_work_min": {"$sum": "$total_work_min"},
                "total_completed": {"$sum": "$completed_sessions"}
            }
        },
        {"$sort": {"total_score": -1}},
        {"$limit": limit}
    ]
    results = await db["DailyStats"].aggregate(pipeline).to_list(None)

    top_list = []
    for idx, r in enumerate(results):
        top_list.append({
            "rank": idx + 1,
            "user_id": r["_id"],
            "score": r["total_score"],
            "work_min": r["total_work_min"],
            "completed": r.get("total_completed", 0)
        })

    return {"period": period, "top_users": top_list}

# ==========================================
# 2. API CỘNG ĐỒNG CHAT TRONG PHÒNG THI ĐUA
# ==========================================
@router.get("/rooms/{room_code}/messages")
async def get_room_messages(request: Request, room_code: str, limit: int = 50):
    """Lấy danh sách tin nhắn của phòng thi đua"""
    db = request.app.database
    if db is None:
        raise HTTPException(status_code=500, detail="Database not connected")

    cursor = db["RoomMessages"].find({"room_code": room_code}).sort("created_at", 1).limit(limit)
    messages = []
    async for doc in cursor:
        created = doc.get("created_at")
        time_str = _format_msg_time(created)
        messages.append({
            "id": str(doc.get("_id", "")),
            "room_code": doc.get("room_code"),
            "sender_id": doc.get("sender_id"),
            "message": doc.get("message"),
            "msg_type": doc.get("msg_type", "user"),
            "time": time_str
        })
    return {"room_code": room_code, "messages": messages}

@router.post("/rooms/{room_code}/messages")
async def send_room_message(request: Request, room_code: str, payload: RoomMessageCreate):
    """Gửi tin nhắn vào phòng thi đua"""
    db = request.app.database
    if db is None:
        raise HTTPException(status_code=500, detail="Database not connected")

    if not payload.message.strip():
        raise HTTPException(status_code=400, detail="Nội dung tin nhắn không được để trống")

    now = get_now()
    doc = {
        "room_code": room_code,
        "sender_id": payload.sender_id,
        "message": payload.message.strip(),
        "msg_type": payload.msg_type,
        "created_at": now
    }
    res = await db["RoomMessages"].insert_one(doc)
    return {
        "status": "success",
        "message_id": str(res.inserted_id),
        "time": _format_msg_time(now)
    }

# ==========================================
# 3. API KẾT BẠN & CHAT RIÊNG (1-1)
# ==========================================
@router.post("/friends/add")
async def add_friend(request: Request, payload: FriendAdd):
    """Kết bạn giữa 2 người tham gia thi đua"""
    db = request.app.database
    if db is None:
        raise HTTPException(status_code=500, detail="Database not connected")

    u1 = payload.user_id.strip()
    u2 = payload.friend_id.strip()
    if not u1 or not u2 or u1 == u2:
        raise HTTPException(status_code=400, detail="Người dùng không hợp lệ")

    friend_pair = sorted([u1, u2])
    doc = {
        "user_a": friend_pair[0],
        "user_b": friend_pair[1],
        "status": "accepted",
        "created_at": get_now()
    }
    await db["Friendships"].update_one(
        {"user_a": friend_pair[0], "user_b": friend_pair[1]},
        {"$setOnInsert": doc},
        upsert=True
    )
    return {"status": "success", "message": f"Đã kết bạn thành công với {u2}!"}

@router.get("/friends/messages")
async def get_direct_messages(request: Request, user_id: str, friend_id: str, limit: int = 50):
    """Lấy lịch sử chat 1-1 giữa 2 bạn bè"""
    db = request.app.database
    if db is None:
        raise HTTPException(status_code=500, detail="Database not connected")

    cursor = db["DirectMessages"].find({
        "$or": [
            {"sender_id": user_id, "receiver_id": friend_id},
            {"sender_id": friend_id, "receiver_id": user_id}
        ]
    }).sort("created_at", 1).limit(limit)

    messages = []
    async for doc in cursor:
        created = doc.get("created_at")
        time_str = _format_msg_time(created)
        messages.append({
            "id": str(doc.get("_id", "")),
            "sender_id": doc.get("sender_id"),
            "receiver_id": doc.get("receiver_id"),
            "message": doc.get("message"),
            "time": time_str
        })
    return {"user_id": user_id, "friend_id": friend_id, "messages": messages}

@router.post("/friends/messages")
async def send_direct_message(request: Request, payload: DirectMessageCreate):
    """Gửi tin nhắn riêng 1-1 cho bạn bè"""
    db = request.app.database
    if db is None:
        raise HTTPException(status_code=500, detail="Database not connected")

    if not payload.message.strip():
        raise HTTPException(status_code=400, detail="Nội dung không được để trống")

    now = get_now()
    doc = {
        "sender_id": payload.sender_id,
        "receiver_id": payload.receiver_id,
        "message": payload.message.strip(),
        "created_at": now
    }
    res = await db["DirectMessages"].insert_one(doc)
    return {
        "status": "success",
        "message_id": str(res.inserted_id),
        "time": _format_msg_time(now)
    }

@router.get("/friends/{user_id}")
async def get_friends_list(request: Request, user_id: str):
    """Lấy danh sách bạn bè của user"""
    db = request.app.database
    if db is None:
        raise HTTPException(status_code=500, detail="Database not connected")

    cursor = db["Friendships"].find({
        "$or": [{"user_a": user_id}, {"user_b": user_id}],
        "status": "accepted"
    })
    friends = []
    async for doc in cursor:
        friend_name = doc["user_b"] if doc["user_a"] == user_id else doc["user_a"]
        friends.append(friend_name)

    return {"user_id": user_id, "friends": friends}

# ==========================================
# THI_DUA_FEATURE_END
# ==========================================
