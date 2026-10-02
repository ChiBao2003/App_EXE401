"""
api/v1/usage_router.py
API endpoints cho hệ thống thu thập dữ liệu sử dụng điện thoại (Digital Wellbeing)
"""

from fastapi import APIRouter, Depends, HTTPException, Query
from datetime import datetime, timedelta
from typing import Optional, List
from pydantic import BaseModel, Field
from motor.motor_asyncio import AsyncIOMotorDatabase

from core.database import get_database
from core.security import get_current_user_id

router = APIRouter(prefix="/usage", tags=["Digital Wellbeing"])


# ── Pydantic Models ──

class UsageEventIn(BaseModel):
    event_type: str = Field(..., description="app_usage | screen_on | screen_off | unlock | distraction")
    package_name: Optional[str] = None
    app_name: Optional[str] = None
    app_category: Optional[str] = None
    duration_ms: Optional[int] = 0
    timestamp: str
    during_pomodoro: bool = False
    pomodoro_session_id: Optional[str] = None
    metadata: Optional[dict] = None


class BulkUsageEventsIn(BaseModel):
    events: List[UsageEventIn]


class DailyUsageSummaryIn(BaseModel):
    date: str
    total_screen_time_ms: int = 0
    total_unlocks: int = 0
    total_distractions_during_pomo: int = 0
    productive_apps_time_ms: int = 0
    distraction_apps_time_ms: int = 0
    top_distraction_apps: List[dict] = Field(default_factory=list)
    top_productive_apps: List[dict] = Field(default_factory=list)
    focus_score: float = 0.0
    pomo_sessions_count: int = 0
    pomo_distraction_rate: float = 0.0


# ── Endpoints ──

@router.post("/events", summary="Bulk upload usage events")
async def upload_usage_events(
    body: BulkUsageEventsIn,
    db: AsyncIOMotorDatabase = Depends(get_database),
    user_id: str = Depends(get_current_user_id),
):
    """
    Upload batch các usage events từ Flutter app.
    Được gọi mỗi khi kết thúc Pomodoro hoặc định kỳ mỗi 5 phút.
    """
    if not body.events:
        return {"inserted": 0}

    docs = []
    for ev in body.events:
        doc = ev.model_dump()
        doc["user_id"] = user_id
        doc["created_at"] = datetime.utcnow()
        docs.append(doc)

    result = await db["usage_events"].insert_many(docs)
    return {"inserted": len(result.inserted_ids)}


@router.post("/daily-summary", summary="Upload/update daily usage summary")
async def upload_daily_summary(
    body: DailyUsageSummaryIn,
    db: AsyncIOMotorDatabase = Depends(get_database),
    user_id: str = Depends(get_current_user_id),
):
    """
    Upload tổng kết sử dụng hàng ngày.
    Upsert: nếu đã có summary cho ngày đó thì update.
    """
    doc = body.model_dump()
    doc["user_id"] = user_id
    doc["updated_at"] = datetime.utcnow()

    result = await db["daily_summaries"].update_one(
        {"date": body.date, "user_id": user_id},
        {"$set": doc},
        upsert=True,
    )
    return {
        "date": body.date,
        "upserted": result.upserted_id is not None,
        "modified": result.modified_count,
    }


@router.get("/analytics", summary="Get usage analytics for a date range")
async def get_usage_analytics(
    start_date: Optional[str] = Query(None, description="YYYY-MM-DD"),
    end_date: Optional[str] = Query(None, description="YYYY-MM-DD"),
    db: AsyncIOMotorDatabase = Depends(get_database),
    user_id: str = Depends(get_current_user_id),
):
    """
    Trả về analytics tổng hợp cho khoảng thời gian.
    Mặc định: 7 ngày gần nhất.
    """
    if not end_date:
        end_dt = datetime.utcnow()
    else:
        end_dt = datetime.strptime(end_date, "%Y-%m-%d") + timedelta(days=1)

    if not start_date:
        start_dt = end_dt - timedelta(days=7)
    else:
        start_dt = datetime.strptime(start_date, "%Y-%m-%d")

    start_str = start_dt.strftime("%Y-%m-%d")
    end_str = end_dt.strftime("%Y-%m-%d")

    # Query daily summaries
    summaries = await db["daily_summaries"].find(
        {"user_id": user_id, "date": {"$gte": start_str, "$lt": end_str}}
    ).sort("date", 1).to_list(length=100)

    # Remove ObjectId for JSON serialization
    for s in summaries:
        s["_id"] = str(s["_id"])

    # Calculate aggregates
    total_screen_time = sum(s.get("total_screen_time_ms", 0) for s in summaries)
    total_unlocks = sum(s.get("total_unlocks", 0) for s in summaries)
    total_distractions = sum(s.get("total_distractions_during_pomo", 0) for s in summaries)
    avg_focus = (
        sum(s.get("focus_score", 0) for s in summaries) / len(summaries)
        if summaries else 0
    )

    return {
        "period": {"start": start_str, "end": end_str},
        "days_count": len(summaries),
        "aggregate": {
            "total_screen_time_ms": total_screen_time,
            "total_unlocks": total_unlocks,
            "total_distractions_during_pomo": total_distractions,
            "avg_focus_score": round(avg_focus, 1),
        },
        "daily_data": summaries,
    }


@router.get("/distractions", summary="Get distraction events for a Pomodoro session")
async def get_session_distractions(
    session_id: str = Query(..., description="Pomodoro session ID"),
    db: AsyncIOMotorDatabase = Depends(get_database),
):
    """
    Trả về danh sách các lần mất tập trung trong 1 phiên Pomodoro.
    """
    events = await db["usage_events"].find(
        {
            "pomodoro_session_id": session_id,
            "event_type": "distraction",
        }
    ).sort("timestamp", 1).to_list(length=200)

    for e in events:
        e["_id"] = str(e["_id"])

    return {"session_id": session_id, "distractions": events}


@router.get("/ai-context", summary="Get usage context for AI prompts")
async def get_ai_usage_context(
    date: Optional[str] = Query(None, description="YYYY-MM-DD, defaults to today"),
    db: AsyncIOMotorDatabase = Depends(get_database),
):
    """
    Trả về dữ liệu sử dụng đã format sẵn cho AI prompt.
    Dùng bởi ai_router.py khi tạo context cho Gemini/OpenAI.
    """
    target_date = date or datetime.utcnow().strftime("%Y-%m-%d")

    summary = await db["daily_summaries"].find_one({"date": target_date})
    if not summary:
        return {"context": "Chưa có dữ liệu sử dụng điện thoại cho ngày này.", "has_data": False}

    # Format screen time
    total_mins = summary.get("total_screen_time_ms", 0) // 60000
    total_h, total_m = divmod(total_mins, 60)

    prod_mins = summary.get("productive_apps_time_ms", 0) // 60000
    prod_h, prod_m = divmod(prod_mins, 60)

    dist_mins = summary.get("distraction_apps_time_ms", 0) // 60000
    dist_h, dist_m = divmod(dist_mins, 60)

    # Top distraction apps
    top_dist = summary.get("top_distraction_apps", [])
    top_dist_text = "\n".join(
        f"  - {app.get('app_name', '?')}: {app.get('time_ms', 0) // 60000}m "
        f"(mở {app.get('open_count', 0)} lần)"
        for app in top_dist[:5]
    ) or "  Không có"

    context = f"""## DỮ LIỆU SỬ DỤNG ĐIỆN THOẠI NGÀY {target_date}
- Tổng thời gian màn hình: {total_h}h {total_m}m
- Số lần mở khóa: {summary.get('total_unlocks', 0)}
- Thời gian dùng app hiệu quả: {prod_h}h {prod_m}m
- Thời gian dùng app giải trí: {dist_h}h {dist_m}m
- Điểm tập trung (Focus Score): {summary.get('focus_score', 0):.0f}/100

## TRONG CÁC PHIÊN POMODORO
- Tổng phiên Pomodoro: {summary.get('pomo_sessions_count', 0)}
- Tỷ lệ mất tập trung: {summary.get('pomo_distraction_rate', 0) * 100:.0f}%
- Số lần bị gián đoạn: {summary.get('total_distractions_during_pomo', 0)}

## APP GÂY MẤT TẬP TRUNG NHẤT
{top_dist_text}
"""

    return {"context": context, "has_data": True, "summary": {
        "focus_score": summary.get("focus_score", 0),
        "screen_time_ms": summary.get("total_screen_time_ms", 0),
        "unlocks": summary.get("total_unlocks", 0),
    }}
