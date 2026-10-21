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

from fastapi import APIRouter, Request, HTTPException, Query, Depends
from pydantic import BaseModel, Field
from typing import List, Optional
import datetime
import uuid
import re
from pymongo.errors import DuplicateKeyError
from core.security import get_current_user_id

router = APIRouter()
# Viet Nam uses UTC+7 year-round. A fixed offset also works in Windows venvs
# without the optional tzdata package required by zoneinfo.
VN_TZ = datetime.timezone(datetime.timedelta(hours=7), name="Asia/Ho_Chi_Minh")

def _today_vn():
    return datetime.datetime.now(VN_TZ).date()

def _iso(dt):
    return (dt.isoformat() + "Z") if isinstance(dt, datetime.datetime) else (str(dt) if dt else None)

def _db(request: Request):
    db = request.app.database
    if db is None:
        raise HTTPException(status_code=500, detail="Database not connected")
    return db

# --- Models ---
class GroupCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=80)
    duration_days: int = Field(..., description="7 or 30 days")

class GroupJoin(BaseModel):
    room_code: str
    user_id: Optional[str] = None

class PomodoroSubmission(BaseModel):
    user_id: Optional[str] = None
    work_min: int = Field(..., ge=1, le=240)
    completed: bool
    pauses: int = Field(..., ge=0, le=240)

class RoomMessageCreate(BaseModel):
    room_code: str
    text: str = Field(..., min_length=1, max_length=500)

class FriendAdd(BaseModel):
    receiver_id: str

class FriendRespond(BaseModel):
    requester_id: str
    action: str

class DirectMessageCreate(BaseModel):
    receiver_id: str
    text: str = Field(..., min_length=1, max_length=500)

class NicknameUpdate(BaseModel):
    nickname: str = Field(..., min_length=2, max_length=25)

class ChatMessageCreate(BaseModel):
    text: str = Field(..., min_length=1, max_length=500)

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


async def snapshot_competition_sessions(db, user_ids=None):
    """Persist one score per synced hardware session before raw-session retention."""
    query = {"user_id": {"$in": user_ids}} if user_ids is not None else {}
    async for session in db["pomodoro_sessions"].find(query):
        synced_at = session.get("synced_at")
        if not synced_at:
            continue
        try:
            timestamp = datetime.datetime.fromisoformat(synced_at.replace("Z", "+00:00"))
            timestamp = timestamp.replace(tzinfo=timestamp.tzinfo or datetime.timezone.utc)
            day = timestamp.astimezone(VN_TZ).date().isoformat()
        except (ValueError, TypeError):
            continue
        hw = session.get("hardware_data") or {}
        completed = bool(hw.get("completed"))
        planned = max(0, int(hw.get("work_min") or 0))
        actual = max(0, int((session.get("computed") or {}).get("actual_work_secs") or 0) // 60)
        minutes = planned if completed else min(planned, actual)
        score = calculate_prs(minutes, completed, max(0, int(hw.get("pauses") or 0)))
        await db["CompetitionSessionScores"].update_one(
            {"_id": str(session["_id"])},
            {"$setOnInsert": {"user_id": session["user_id"], "date": day,
                              "score": score, "work_min": minutes,
                              "completed": int(completed)}},
            upsert=True,
        )

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
    now = datetime.datetime.now(VN_TZ)
    if period == "today":
        return now.strftime("%Y-%m-%d")
    elif period == "week":
        start = now - datetime.timedelta(days=now.weekday())  # Thứ 2 tuần này
        return start.strftime("%Y-%m-%d")
    elif period == "month":
        return now.strftime("%Y-%m-01")  # Ngày 1 tháng này
    return None  # "all" => không lọc

async def _room_for_member(db, room_code: str, user_id: str):
    group = await db["Groups"].find_one({"room_code": room_code.upper()})
    if not group:
        raise HTTPException(status_code=404, detail="Khong tim thay ma phong")
    if user_id not in group.get("members", []):
        raise HTTPException(status_code=403, detail="Ban khong phai thanh vien phong")
    return group


async def _ensure_room_read_state(db, room_code: str, user_id: str):
    key = f"{room_code.upper()}:{user_id}"
    await db["RoomReadStates"].update_one(
        {"_id": key},
        {"$setOnInsert": {"room_code": room_code.upper(), "user_id": user_id,
                          "last_read_at": datetime.datetime.utcnow()}},
        upsert=True,
    )
    return key


@router.get("/groups/{room_code}/unread-status")
async def room_unread_status(request: Request, room_code: str,
                             current_user_id: str = Depends(get_current_user_id)):
    db = _db(request)
    await _room_for_member(db, room_code, current_user_id)
    key = await _ensure_room_read_state(db, room_code, current_user_id)
    state = await db["RoomReadStates"].find_one({"_id": key})
    query = {"room_code": room_code.upper(), "user_id": {"$ne": current_user_id},
             "created_at": {"$gt": state["last_read_at"]}}
    new_count = await db["RoomMessages"].count_documents(query)
    old_count = await db["CompetitionMessages"].count_documents(query)
    return {"room_code": room_code.upper(), "unread_count": new_count + old_count}


@router.get("/groups/messages/{room_code}")
@router.get("/groups/{room_code}/messages")
async def get_room_messages(
    request: Request,
    room_code: str,
    current_user_id: str = Depends(get_current_user_id),
):
    db = request.app.database
    if db is None:
        raise HTTPException(status_code=500, detail="Database not connected")
    await _room_for_member(db, room_code, current_user_id)
    viewed_at = datetime.datetime.utcnow()
    cursor = db["RoomMessages"].find(
        {"room_code": room_code.upper()}
    ).sort("created_at", -1).limit(50)
    messages = await cursor.to_list(length=50)
    old_messages = await db["CompetitionMessages"].find(
        {"room_code": room_code.upper()}
    ).sort("created_at", -1).limit(50).to_list(length=50)
    messages = sorted(messages + old_messages, key=lambda item: item["created_at"], reverse=True)[:50]
    key = await _ensure_room_read_state(db, room_code, current_user_id)
    await db["RoomReadStates"].update_one({"_id": key}, {"$max": {"last_read_at": viewed_at}})
    return {"messages": [
        {
            "id": str(message["_id"]),
            "user_id": message["user_id"],
            "sender_name": message["sender_name"],
            "text": message["text"],
            "created_at": message["created_at"].isoformat() + "Z",
        }
        for message in reversed(messages)
    ]}


@router.post("/groups/messages", status_code=201)
async def post_room_message_new(
    request: Request, payload: RoomMessageCreate,
    current_user_id: str = Depends(get_current_user_id),
):
    return await post_room_message(
        request, payload.room_code, ChatMessageCreate(text=payload.text), current_user_id
    )

@router.post("/groups/{room_code}/messages", status_code=201)
async def post_room_message(
    request: Request,
    room_code: str,
    payload: ChatMessageCreate,
    current_user_id: str = Depends(get_current_user_id),
):
    db = request.app.database
    if db is None:
        raise HTTPException(status_code=500, detail="Database not connected")
    group = await _room_for_member(db, room_code, current_user_id)
    if _check_expired(group):
        raise HTTPException(status_code=400, detail="Phong da het han thi dua")
    text = payload.text.strip()
    if not text:
        raise HTTPException(status_code=422, detail="Tin nhan khong duoc de trong")
    user = await db["users"].find_one({"_id": current_user_id}, {"display_name": 1})
    message = {
        "room_code": room_code.upper(),
        "user_id": current_user_id,
        "sender_name": (user or {}).get("display_name") or current_user_id,
        "text": text,
        "created_at": datetime.datetime.utcnow(),
    }
    result = await db["RoomMessages"].insert_one(message)
    return {
        "id": str(result.inserted_id),
        "user_id": current_user_id,
        "sender_name": message["sender_name"],
        "text": text,
        "created_at": message["created_at"].isoformat() + "Z",
    }


# --- Endpoints ---
@router.post("/groups")
async def create_group(
    request: Request,
    payload: GroupCreate,
    current_user_id: str = Depends(get_current_user_id),
):
    db = request.app.database
    if db is None:
        raise HTTPException(status_code=500, detail="Database not connected")
    
    if payload.duration_days not in (7, 30):
        raise HTTPException(status_code=422, detail="Thoi han phai la 7 hoac 30 ngay")
    room_code = generate_room_code()
    while await db["Groups"].find_one({"room_code": room_code}):
        room_code = generate_room_code()
    group_doc = {
        "room_code": room_code,
        "name": payload.name,
        "duration_days": payload.duration_days,
        "members": [current_user_id],
        "created_by": current_user_id,
        "created_at": datetime.datetime.utcnow()
    }
    
    await db["Groups"].insert_one(group_doc)
    await _ensure_room_read_state(db, room_code, current_user_id)
    return {
        "status": "success", 
        "room_code": room_code, 
        "message": f"Tao phong '{payload.name}' thanh cong! Ma phong: {room_code}"
    }

@router.post("/groups/join")
async def join_group(
    request: Request,
    payload: GroupJoin,
    current_user_id: str = Depends(get_current_user_id),
):
    db = request.app.database
    if db is None:
        raise HTTPException(status_code=500, detail="Database not connected")
    
    room_code = payload.room_code.strip().upper()
    group = await db["Groups"].find_one({"room_code": room_code})
    if not group:
        raise HTTPException(status_code=404, detail="Khong tim thay ma phong")
    
    # Kiểm tra phòng đã hết hạn chưa
    if _check_expired(group):
        raise HTTPException(status_code=400, detail="Phong da het han thi dua")
    
    # Kiểm tra giới hạn thành viên (tối đa 5 người để cạnh tranh tốt)
    members = group.get("members", [])
    if current_user_id not in members:
        if len(members) >= 5:
            raise HTTPException(status_code=400, detail="Phong da day (Toi da 5 nguoi)")
            
        result = await db["Groups"].update_one(
            {"room_code": room_code, "members": {"$ne": current_user_id},
             "$expr": {"$lt": [{"$size": "$members"}, 5]}},
            {"$addToSet": {"members": current_user_id}}
        )
        if not result.modified_count:
            raise HTTPException(status_code=400, detail="Phong da day (Toi da 5 nguoi)")
        
    await _ensure_room_read_state(db, room_code, current_user_id)
    return {"status": "success", "message": "Da tham gia phong thi dua thanh cong!"}

@router.post("/submit")
async def submit_session(
    request: Request,
    payload: PomodoroSubmission,
    current_user_id: str = Depends(get_current_user_id),
):
    db = request.app.database
    if db is None:
        raise HTTPException(status_code=500, detail="Database not connected")
    
    # 1. Tính toán điểm PRS theo logic cứng (không dùng AI)
    prs = calculate_prs(payload.work_min, payload.completed, payload.pauses)
    
    # 2. Lưu vào CSDL tổng hợp theo ngày với authenticated user_id
    today = _today_vn().isoformat()
    
    await db["DailyStats"].update_one(
        {"user_id": current_user_id, "date": today},
        {
            "$inc": {
                "total_score": prs, 
                "total_work_min": payload.work_min,
                "completed_sessions": 1 if payload.completed else 0
            }
        },
        upsert=True
    )

    user = await db["users"].find_one({"_id": current_user_id}, {"display_name": 1})
    sender_name = (user or {}).get("display_name") or current_user_id
    announcement = f"🎉 {sender_name} vừa cày xong phiên {payload.work_min} phút (+{prs} điểm PRS)!"
    rooms = await db["Groups"].find({"members": current_user_id}, {"room_code": 1}).to_list(None)
    if rooms:
        await db["RoomMessages"].insert_many([
            {"room_code": room["room_code"], "user_id": "system",
             "sender_name": "Hệ thống", "text": announcement,
             "created_at": datetime.datetime.utcnow()}
            for room in rooms
        ])
    
    return {
        "status": "success", 
        "prs_earned": prs, 
        "message": f"Tuyet voi! Ban nhan duoc {prs} diem PRS."
    }

@router.get("/leaderboard/{room_code}")
async def get_leaderboard(
    request: Request, 
    room_code: str,
    period: str = Query(default="all", pattern="^(today|week|month|all)$"),
    current_user_id: str = Depends(get_current_user_id),
):
    """
    Lấy bảng xếp hạng tổng điểm của phòng thi đua.
    Query param `period`: today | week | month | all
    Yêu cầu JWT token và kiểm tra thành viên: current_user_id phải nằm trong group["members"].
    """
    db = request.app.database
    if db is None:
        raise HTTPException(status_code=500, detail="Database not connected")
    
    group = await _room_for_member(db, room_code, current_user_id)
    members = group.get("members", [])
    
    # Kiểm tra hết hạn
    expired = _check_expired(group)
    
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
    
    totals = {user_id: {"score": 0, "work_min": 0, "completed": 0} for user_id in members}
    for result in results:
        entry = totals[result["_id"]]
        entry["score"] += result["total_score"]
        entry["work_min"] += result["total_work_min"]
        entry["completed"] += result.get("total_completed", 0)

    await snapshot_competition_sessions(db, members)
    score_filter = {"user_id": {"$in": members}}
    if date_start:
        score_filter["date"] = {"$gte": date_start}
    async for session_score in db["CompetitionSessionScores"].find(score_filter):
        entry = totals.get(session_score.get("user_id"))
        if entry is None:
            continue
        entry["score"] += session_score["score"]
        entry["work_min"] += session_score["work_min"]
        entry["completed"] += session_score["completed"]

    user_cursor = db["users"].find({"_id": {"$in": members}}, {"display_name": 1})
    names = {user["_id"]: user.get("display_name") or user["_id"] async for user in user_cursor}
    ranked = sorted(members, key=lambda user_id: (-totals[user_id]["score"], user_id))
    leaderboard = [
        {
            "rank": idx + 1,
            "user_id": user_id,
            "display_name": names.get(user_id, user_id),
            **totals[user_id],
        }
        for idx, user_id in enumerate(ranked)
    ]
        
    return {
        "room_code": room_code, 
        "group_name": group["name"],
        "duration_days": group["duration_days"],
        "expired": expired,
        "period": period,
        "participant_count": len(members),
        "leaderboard": leaderboard
    }


async def _user_label(db, user_id):
    user = await db["users"].find_one({"_id": user_id}, {"display_name": 1})
    return (user or {}).get("display_name") or user_id


async def _require_friend(db, user_id, friend_id):
    pair = await db["Friendships"].find_one({
        "status": "accepted",
        "$or": [
            {"requester_id": user_id, "receiver_id": friend_id},
            {"requester_id": friend_id, "receiver_id": user_id},
        ],
    })
    if not pair:
        raise HTTPException(status_code=403, detail="Hai nguoi chua ket ban")


@router.post("/nickname/update")
async def update_nickname(request: Request, payload: NicknameUpdate,
                          current_user_id: str = Depends(get_current_user_id)):
    db = _db(request)
    nickname = payload.nickname.strip()
    if not 2 <= len(nickname) <= 25:
        raise HTTPException(status_code=422, detail="Biet danh phai dai 2-25 ky tu")
    user = await db["users"].find_one({"_id": current_user_id})
    if not user:
        raise HTTPException(status_code=404, detail="Khong tim thay tai khoan")
    if nickname == user.get("display_name"):
        raise HTTPException(status_code=422, detail="Biet danh moi phai khac ten cu")
    if await db["users"].find_one({"display_name": {"$regex": f"^{re.escape(nickname)}$", "$options": "i"}, "_id": {"$ne": current_user_id}}):
        raise HTTPException(status_code=409, detail="Biet danh da duoc su dung")
    await db["users"].update_one({"_id": current_user_id}, {"$set": {"display_name": nickname}})
    # IDs are immutable UUIDs. Keep relationship and score keys unchanged.
    await db["RoomMessages"].update_many({"user_id": current_user_id}, {"$set": {"sender_name": nickname}})
    await db["CompetitionMessages"].update_many({"user_id": current_user_id}, {"$set": {"sender_name": nickname}})
    await db["DirectMessages"].update_many({"sender_id": current_user_id}, {"$set": {"sender_name": nickname}})
    return {"user_id": current_user_id, "display_name": nickname}


@router.post("/friends/add")
async def add_friend(request: Request, payload: FriendAdd,
                     current_user_id: str = Depends(get_current_user_id)):
    db = _db(request)
    target = payload.receiver_id.strip()
    if target == current_user_id:
        raise HTTPException(status_code=422, detail="Khong the tu ket ban")
    if not await db["users"].find_one({"_id": target}):
        raise HTTPException(status_code=404, detail="Khong tim thay nguoi dung")
    friendships = db["Friendships"]
    incoming = await friendships.find_one({"requester_id": target, "receiver_id": current_user_id})
    if incoming:
        if incoming["status"] == "pending":
            await friendships.update_one({"_id": incoming["_id"]}, {"$set": {"status": "accepted"}})
        return {"status": "accepted"}
    outgoing = await friendships.find_one({"requester_id": current_user_id, "receiver_id": target})
    if outgoing:
        return {"status": outgoing["status"]}
    pair_key = "friend:" + ":".join(sorted((current_user_id, target)))
    try:
        await friendships.insert_one({"_id": pair_key, "requester_id": current_user_id,
                                      "receiver_id": target, "status": "pending",
                                      "created_at": datetime.datetime.utcnow()})
        return {"status": "pending"}
    except DuplicateKeyError:
        reverse = await friendships.find_one({"_id": pair_key})
        if reverse and reverse["requester_id"] == target:
            await friendships.update_one({"_id": pair_key}, {"$set": {"status": "accepted"}})
            return {"status": "accepted"}
        return {"status": (reverse or {}).get("status", "pending")}


@router.post("/friends/respond")
async def respond_friend(request: Request, payload: FriendRespond,
                         current_user_id: str = Depends(get_current_user_id)):
    db = _db(request)
    if payload.action not in ("accept", "decline"):
        raise HTTPException(status_code=422, detail="action phai la accept hoac decline")
    query = {"requester_id": payload.requester_id, "receiver_id": current_user_id,
             "status": "pending"}
    if payload.action == "accept":
        result = await db["Friendships"].update_one(query, {"$set": {"status": "accepted"}})
        found = result.modified_count
    else:
        result = await db["Friendships"].delete_one(query)
        found = result.deleted_count
    if not found:
        raise HTTPException(status_code=404, detail="Khong tim thay loi moi")
    return {"status": "accepted" if payload.action == "accept" else "declined"}


@router.get("/friends/unread-status")
async def unread_status(request: Request, user_id: Optional[str] = None,
                        current_user_id: str = Depends(get_current_user_id)):
    db = _db(request)
    if user_id and user_id != current_user_id:
        raise HTTPException(status_code=403, detail="Khong co quyen xem thong bao")
    invites = await db["Friendships"].count_documents({"receiver_id": current_user_id, "status": "pending"})
    unread = await db["DirectMessages"].find({"receiver_id": current_user_id, "is_read": False}).to_list(None)
    by_sender = {}
    for message in unread:
        sender = message["sender_id"]
        by_sender[sender] = by_sender.get(sender, 0) + 1
    return {"pending_requests": invites, "unread_messages": len(unread),
            "unread_by_sender": by_sender, "total": invites + len(unread)}


@router.post("/friends/messages", status_code=201)
async def send_direct_message(request: Request, payload: DirectMessageCreate,
                              current_user_id: str = Depends(get_current_user_id)):
    db = _db(request)
    await _require_friend(db, current_user_id, payload.receiver_id)
    text = payload.text.strip()
    if not text:
        raise HTTPException(status_code=422, detail="Tin nhan khong duoc de trong")
    message = {"sender_id": current_user_id, "receiver_id": payload.receiver_id,
               "sender_name": await _user_label(db, current_user_id), "text": text,
               "is_read": False, "created_at": datetime.datetime.utcnow()}
    result = await db["DirectMessages"].insert_one(message)
    return {"id": str(result.inserted_id), "sender_id": current_user_id,
            "receiver_id": payload.receiver_id, "text": text,
            "is_read": False, "created_at": _iso(message["created_at"])}


@router.get("/friends/messages")
async def get_direct_messages(request: Request, friend_id: str, user_id: Optional[str] = None,
                              current_user_id: str = Depends(get_current_user_id)):
    db = _db(request)
    if user_id and user_id != current_user_id:
        raise HTTPException(status_code=403, detail="Khong co quyen xem tin nhan")
    await _require_friend(db, current_user_id, friend_id)
    query = {"$or": [
        {"sender_id": current_user_id, "receiver_id": friend_id},
        {"sender_id": friend_id, "receiver_id": current_user_id},
    ]}
    messages = await db["DirectMessages"].find(query).sort("created_at", -1).limit(100).to_list(100)
    await db["DirectMessages"].update_many(
        {"sender_id": friend_id, "receiver_id": current_user_id, "is_read": False},
        {"$set": {"is_read": True}})
    return {"messages": [{"id": str(item["_id"]), "sender_id": item["sender_id"],
                          "receiver_id": item["receiver_id"], "text": item["text"],
                          "sender_name": item.get("sender_name", ""),
                          "is_read": item.get("is_read", False),
                          "created_at": _iso(item["created_at"])}
                         for item in reversed(messages)]}


@router.get("/friends/{user_id}")
async def list_friends(request: Request, user_id: str,
                       current_user_id: str = Depends(get_current_user_id)):
    db = _db(request)
    if user_id != current_user_id:
        raise HTTPException(status_code=403, detail="Khong co quyen xem danh sach ban be")
    rows = await db["Friendships"].find({"$or": [
        {"requester_id": user_id}, {"receiver_id": user_id}
    ]}).to_list(None)
    result = {"friends": [], "sent_requests": [], "incoming_requests": []}
    for row in rows:
        other = row["receiver_id"] if row["requester_id"] == user_id else row["requester_id"]
        item = {"user_id": other, "display_name": await _user_label(db, other),
                "created_at": _iso(row.get("created_at"))}
        if row["status"] == "accepted":
            result["friends"].append(item)
        elif row["requester_id"] == user_id:
            result["sent_requests"].append(item)
        else:
            result["incoming_requests"].append(item)
    return result


@router.get("/stats/summary")
async def competition_summary(request: Request, period: str = Query("today", pattern="^(today|week|month)$"),
                              user_id: Optional[str] = None,
                              current_user_id: str = Depends(get_current_user_id)):
    db = _db(request)
    if user_id and user_id != current_user_id:
        raise HTTPException(status_code=403, detail="Khong co quyen xem thong ke")
    today = _today_vn()
    start = _get_date_filter(period)
    stats = await db["DailyStats"].find({"date": {"$gte": (today - datetime.timedelta(days=30)).isoformat()}}).to_list(None)
    daily = {}
    totals = {}
    for row in stats:
        uid, date = row.get("user_id"), row.get("date")
        minutes = max(0, int(row.get("total_work_min", 0)))
        if uid == current_user_id:
            daily[date] = daily.get(date, 0) + minutes
        if date >= start:
            totals[uid] = totals.get(uid, 0) + int(row.get("total_score", 0))
    await snapshot_competition_sessions(db)
    async for session_score in db["CompetitionSessionScores"].find({
        "date": {"$gte": (today - datetime.timedelta(days=30)).isoformat()}
    }):
        uid, date = session_score["user_id"], session_score["date"]
        if uid == current_user_id:
            daily[date] = daily.get(date, 0) + session_score["work_min"]
        if date >= start:
            totals[uid] = totals.get(uid, 0) + session_score["score"]
    days = [{"date": (today - datetime.timedelta(days=6 - i)).isoformat(),
             "minutes": daily.get((today - datetime.timedelta(days=6 - i)).isoformat(), 0)}
            for i in range(7)]
    streak = 0
    cursor = today
    if not daily.get(cursor.isoformat()):
        cursor -= datetime.timedelta(days=1)
    while daily.get(cursor.isoformat(), 0) > 0:
        streak += 1
        cursor -= datetime.timedelta(days=1)
    minutes = sum(value for date, value in daily.items() if date >= start)
    target = {"today": 120, "week": 840, "month": 3600}[period]
    top = sorted(totals.items(), key=lambda entry: -entry[1])[:5]
    return {"period": period, "minutes": minutes, "target_minutes": target,
            "completion_percent": round(minutes * 100 / target, 1), "streak": streak,
            "last_7_days": days,
            "top_five": [{"user_id": uid, "display_name": await _user_label(db, uid),
                          "score": score} for uid, score in top]}

# ==========================================
# THI_DUA_FEATURE_END
# ==========================================
