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
    return datetime.datetime.utcnow() > expiry

def _get_date_filter(period: str) -> Optional[str]:
    """Trả về ngày bắt đầu lọc dựa theo period (today/week/month)"""
    now = datetime.datetime.utcnow()
    if period == "today":
        return now.strftime("%Y-%m-%d")
    elif period == "week":
        start = now - datetime.timedelta(days=now.weekday())  # Thứ 2 tuần này
        return start.strftime("%Y-%m-%d")
    elif period == "month":
        return now.strftime("%Y-%m-01")  # Ngày 1 tháng này
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
        "created_at": datetime.datetime.utcnow()
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
    
    # 2. Lưu vào CSDL tổng hợp theo ngày
    today = datetime.datetime.utcnow().strftime("%Y-%m-%d")
    
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
    
    return {
        "status": "success", 
        "prs_earned": prs, 
        "message": f"Tuyet voi! Ban nhan duoc {prs} diem PRS."
    }

@router.get("/leaderboard/{room_code}")
async def get_leaderboard(
    request: Request, 
    room_code: str,
    period: str = Query(default="all", regex="^(today|week|month|all)$")
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
# THI_DUA_FEATURE_END
# ==========================================
