"""
api/v1/ai_router.py - AI Feature Endpoints
Bao gom: Adaptive Pomodoro, Daily Coach, Burnout Risk, AI Work Schedule
"""
from fastapi import APIRouter, Depends, Query
from motor.motor_asyncio import AsyncIOMotorDatabase
from datetime import datetime, timedelta
from typing import Optional, List
from dotenv import load_dotenv

load_dotenv()

from core.database import get_database
from core.security import get_current_user_id
from domain.entities.productivity_entity import (
    AIRecommendation, SessionFeedback, ProductivityLog, BurnoutRiskResponse
)
from application.ai.adaptive_pomodoro_agent import AdaptivePomodoroAgent
from application.ai.digital_twin_service import DigitalTwinService
from application.context.context_service import ContextService
from application.ai.burnout_detector import BurnoutDetector
from application.ai.time_window import now_vn
from application.ai.ai_coach_orchestrator import AICoachOrchestrator
from pydantic import BaseModel

router = APIRouter()


# ============================================================
# 1. Adaptive Pomodoro - Goi y chu ky tiep theo
# ============================================================
@router.get(
    "/pomodoro/recommend",
    response_model=AIRecommendation,
    summary="Q-Learning: Goi y chu ky Pomodoro phu hop nhat"
)
async def recommend_pomodoro(
    concentration_score: float = Query(default=60.0, ge=0, le=100,
                                       description="Diem tap trung hien tai (0-100)"),
    task_type: str = Query(default="general",
                           description="Loai task: coding/reading/meeting/general"),
    user_id: str = Depends(get_current_user_id),
    db: AsyncIOMotorDatabase = Depends(get_database),
):
    """
    Lay goi y work/break duration cho phien Pomodoro tiep theo.
    AI dua vao: Diem tap trung, lich su session hom nay, gio trong ngay.
    """
    hour = now_vn().hour  # gio VN thuc, khong phu thuoc mui gio server

    # Tinh completion_rate va break_skipped tu 3 session gan nhat
    recent = await db["productivity_logs"].find(
        {"user_id": user_id},
        sort=[("timestamp", -1)],
    ).to_list(length=3)

    completion_rate = 70.0  # Default
    break_skipped = False
    if recent:
        completed_count = sum(1 for s in recent if s.get("completed", False))
        completion_rate = (completed_count / len(recent)) * 100.0
        break_skipped = recent[0].get("break_skipped", False)

    agent = AdaptivePomodoroAgent(user_id=user_id, db=db)
    return await agent.recommend(
        hour=hour,
        concentration_score=concentration_score,
        completion_rate=completion_rate,
        break_skipped=break_skipped,
        task_type=task_type,
    )


# ============================================================
# 2. Session Feedback - Cap nhat Q-table sau phien
# ============================================================
@router.post(
    "/pomodoro/feedback",
    summary="Gui ket qua phien Pomodoro de AI hoc tiep"
)
async def submit_session_feedback(
    feedback: SessionFeedback,
    db: AsyncIOMotorDatabase = Depends(get_database),
):
    """
    Sau khi phien Pomodoro ket thuc, gui du lieu nay de:
    1. Luu vao productivity_logs (MongoDB)
    2. Cap nhat Q-table cua user (online learning)
    """
    # Luu log
    log_doc = {
        "user_id": feedback.user_id,
        "session_id": feedback.session_id,
        "work_min": feedback.work_min,
        "break_min": feedback.break_min,
        "concentration_score": feedback.concentration_score,
        "completion_rate": feedback.completion_rate,
        "interruptions": feedback.interruptions,
        "break_skipped": feedback.break_skipped,
        "task_type": feedback.task_type,
        "completed": feedback.completion_rate >= 90,
        "timestamp": datetime.utcnow().isoformat(),
        "hour_of_day": feedback.hour_of_day,
        "day_of_week": feedback.day_of_week,
        "recommendation_id": feedback.recommendation_id
    }
    await db["productivity_logs"].insert_one(log_doc)
    
    # Update AI Recommendation Log Feedback Loop
    if feedback.recommendation_id:
        rec_log = await db["ai_recommendation_logs"].find_one({"recommendation_id": feedback.recommendation_id})
        if rec_log:
            cand = rec_log.get("candidate", {})
            accepted = False
            
            # Check if user actually followed the recommendation
            if (cand.get("work_min") == feedback.work_min and 
                cand.get("break_min") == feedback.break_min and
                cand.get("candidate_type") == feedback.task_type):
                accepted = True
                
            await db["ai_recommendation_logs"].update_one(
                {"recommendation_id": feedback.recommendation_id},
                {"$set": {
                    "accepted": accepted,
                    "completed": feedback.completion_rate >= 90,
                    "outcome": feedback.concentration_score,
                    "actual_work_min": feedback.work_min,
                    "actual_break_min": feedback.break_min,
                    "actual_task_type": feedback.task_type
                }}
            )

    # Cap nhat Q-table
    agent = AdaptivePomodoroAgent(user_id=feedback.user_id, db=db)
    update_result = await agent.update(feedback)

    return {
        "status": "ok",
        "message": "Da luu log va cap nhat AI model",
        "reward": update_result["reward"],
    }


# ============================================================
# 3. Log Productivity (tu app gui len)
# ============================================================
@router.post("/productivity/log", summary="Luu ban ghi nang suat")
async def log_productivity(
    log: ProductivityLog,
    user_id: str = Depends(get_current_user_id),
    db: AsyncIOMotorDatabase = Depends(get_database),
):
    doc = log.model_dump()
    doc["user_id"] = user_id
    await db["productivity_logs"].insert_one(doc)
    return {"status": "ok", "message": "Da luu ban ghi nang suat"}


# ============================================================
# 4. Burnout Risk Assessment (Rule-based Phase 1, LSTM Phase 2)
# ============================================================
# Map mức BRIX (LOW/MODERATE/CRITICAL, 3 mức theo bài báo) -> key Flutter (low/medium/high/critical).
# Bài báo chỉ có 3 mức nên không có mức 'high' riêng; mức cao nhất giữ là 'critical'.
_BRIX_TO_APP_LEVEL = {"LOW": "low", "MODERATE": "medium", "CRITICAL": "critical"}


@router.get(
    "/burnout/risk",
    response_model=BurnoutRiskResponse,
    summary="Danh gia nguy co Burnout (BRIX proxy) dua tren 15 ngay gan nhat"
)
async def get_burnout_risk(
    user_id: str = Depends(get_current_user_id),
    db: AsyncIOMotorDatabase = Depends(get_database),
):
    """
    Dung CHUNG BurnoutDetector voi AI Coach de moi noi hien cung mot con so.
    Moi chi bao trong `indicators` deu lay tu so lieu do duoc that.
    """
    b = await BurnoutDetector(db).calculate_burnout_risk(user_id)
    f = b.get("factors", {})

    if b["data_confidence"] == "none":
        return BurnoutRiskResponse(
            risk_score=0.0, risk_level="low",
            indicators=["Chua co du lieu de phan tich"],
            advice="Hay bat dau theo doi phien lam viec de nhan khuyen nghi chinh xac."
        )

    indicators = [f"Phan tich {f.get('sessions_analyzed', 0)} phien trong {f.get('window_days')} ngay gan nhat "
                  f"(BRIX-W={b['brix_w']})"]
    if b["data_confidence"] == "low":
        indicators.append("Du lieu con it (<5 phien) nen ket qua chi mang tinh tham khao")
    if f.get("avg_daily_work_min") is not None:
        indicators.append(f"Lam viec trung binh {f['avg_daily_work_min'] / 60:.1f} gio/ngay")
    if f.get("skipped_break_rate") is not None:
        indicators.append(f"Bo qua break: {f['skipped_break_rate'] * 100:.0f}% cac phien")
    if f.get("avg_pauses_per_session") is not None:
        indicators.append(f"Ngat giua phien: trung binh {f['avg_pauses_per_session']:.1f} lan")
    if f.get("incomplete_rate") is not None:
        indicators.append(f"Ty le bo do phien: {f['incomplete_rate'] * 100:.0f}%")
    if f.get("avg_focus") is not None:
        indicators.append(f"Diem tap trung trung binh: {f['avg_focus']:.0f}/100")
    if f.get("late_night_ratio"):
        indicators.append(f"Lam viec khuya (23h-5h): {f['late_night_ratio'] * 100:.0f}% cac phien")
    if f.get("unlocks_per_day") is not None:
        indicators.append(f"Mo khoa dien thoai: {f['unlocks_per_day']:.0f} lan/ngay")

    level = _BRIX_TO_APP_LEVEL.get(b["risk_level"], "low")
    advice = {
        "critical": ("NGUY CO CAO! Ban dang co dau hieu kiet suc nghiem trong. "
                     "Hay nghi ngoi, giam tai cong viec va ngu du giac."),
        "medium": ("Co mot so dau hieu can chu y. Hay dam bao nghi ngoi day du "
                   "va khong bo qua break trong phien Pomodoro."),
        "low": "Ban dang lam viec o muc do lanh manh. Tiep tuc duy tri nhip do nay!",
    }[level]

    return BurnoutRiskResponse(
        risk_score=b["burnout_risk_score"],
        risk_level=level,
        indicators=indicators,
        advice=advice,
    )

class AIChatRequest(BaseModel):
    user_prompt: str
    # Trang thai dong ho do App gui len; None = khong biet (khong bia 'connected=True')
    watch_connected: Optional[bool] = None
    watch_battery: Optional[int] = None
    watch_screen: Optional[str] = None
    lat: Optional[float] = None
    lon: Optional[float] = None

@router.post("/coach/chat", summary="Chat với AI Coach với Context Injection & Tool Calling")
async def chat_with_ai_coach(
    req: AIChatRequest,
    user_id: str = Depends(get_current_user_id),
    db: AsyncIOMotorDatabase = Depends(get_database)
):
    twin_svc = DigitalTwinService(db)
    ctx_svc = ContextService()  # khoa lay tu bien moi truong OPENWEATHER_API_KEY
    burnout_svc = BurnoutDetector(db)

    digital_twin = await twin_svc.compute_profile(user_id)
    # ── Truyền tọa độ GPS thật vào hàm get_context ──
    context = await ctx_svc.get_context(user_id, lat=req.lat, lon=req.lon)
    burnout = await burnout_svc.calculate_burnout_risk(user_id)
    digital_twin["burnout"] = burnout
    digital_twin["burnout_risk_score"] = burnout.get("burnout_risk_score", 0.0)

    # ── Phase 2: Inject Digital Wellbeing usage data ──
    # daily_summaries lưu date theo ngày VN → dùng now_vn() thay vì utcnow()
    today_str = now_vn().strftime("%Y-%m-%d")
    usage_summary = await db["daily_summaries"].find_one(
        {"user_id": user_id, "date": today_str}
    )
    if usage_summary:
        total_mins = usage_summary.get("total_screen_time_ms", 0) // 60000
        total_h, total_m = divmod(total_mins, 60)
        prod_mins = usage_summary.get("productive_apps_time_ms", 0) // 60000
        dist_mins = usage_summary.get("distraction_apps_time_ms", 0) // 60000
        top_dist = usage_summary.get("top_distraction_apps", [])
        top_dist_text = ", ".join(
            f"{app.get('app_name', '?')}({app.get('time_ms', 0) // 60000}m)"
            for app in top_dist[:3]
        ) or "Không có"

        digital_twin["phone_usage"] = {
            "screen_time": f"{total_h}h {total_m}m",
            "unlocks": usage_summary.get("total_unlocks", 0),
            "focus_score": usage_summary.get("focus_score", 0),
            "productive_time_min": prod_mins,
            "distraction_time_min": dist_mins,
            "top_distraction_apps": top_dist_text,
            "pomo_distractions": usage_summary.get("total_distractions_during_pomo", 0),
            "pomo_distraction_rate": usage_summary.get("pomo_distraction_rate", 0),
        }

    watch_status = {
        "connected": req.watch_connected,
        "battery": req.watch_battery,
        "current_screen": req.watch_screen,
    }

    # Fetch past chat history (last 10 turns)
    history_cursor = db["ai_chat_history"].find({"user_id": user_id}).sort("timestamp", -1).limit(10)
    history_docs = await history_cursor.to_list(length=10)
    chat_history = []
    for doc in reversed(history_docs):
        chat_history.append({"role": "user", "parts": [{"text": doc["user_prompt"]}]})
        chat_history.append({"role": "model", "parts": [{"text": doc["ai_reply"]}]})

    import logging
    logger = logging.getLogger("api")
    
    logger.info("=" * 60)
    logger.info(f"🧠 [AI COACH] Lịch sử trò chuyện ({len(chat_history)//2} lượt trước):")
    for msg in chat_history:
        logger.info(f"   [{msg['role'].upper()}]: {msg['parts'][0]['text']}")
    
    logger.info("-" * 60)
    logger.info(f"👤 [USER HỎI]: {req.user_prompt}")
    
    orchestrator = AICoachOrchestrator()
    res = await orchestrator.chat(
        user_id=user_id,
        user_prompt=req.user_prompt,
        digital_twin=digital_twin,
        context=context,
        watch_status=watch_status,
        chat_history=chat_history
    )
    
    logger.info(f"🤖 [AI TRẢ LỜI]: {res.get('reply', '')}")
    logger.info("=" * 60)
    
    # In ra thẳng terminal để dễ debug
    print("\n" + "=" * 60)
    print(f"👤 [USER HỎI]: {req.user_prompt}")
    print(f"🤖 [AI TRẢ LỜI]: {res.get('reply', '')}")
    print("=" * 60 + "\n")
    
    # Save current turn to history
    await db["ai_chat_history"].insert_one({
        "user_id": user_id,
        "user_prompt": req.user_prompt,
        "ai_reply": res.get("reply", ""),
        "timestamp": datetime.utcnow().isoformat()
    })

    # ── Auto-detect & persist generate_work_schedule tool call ──
    schedule_plan = None
    tool_calls = res.get("tool_calls", [])
    for tc in tool_calls:
        if tc.get("tool") == "generate_work_schedule":
            schedule_plan = tc.get("params", {})
            break

    if schedule_plan:
        import uuid as _uuid
        schedule_id = str(_uuid.uuid4())
        schedule_doc = {
            "schedule_id": schedule_id,
            "user_id": user_id,
            "target_date": schedule_plan.get("target_date", datetime.utcnow().strftime("%Y-%m-%d")),
            "grade_score": schedule_plan.get("grade_score", 0),
            "grade_letter": schedule_plan.get("grade_letter", "B"),
            "grade_rationale": schedule_plan.get("grade_rationale", ""),
            "schedule_blocks": schedule_plan.get("schedule_blocks", []),
            "total_work_minutes": schedule_plan.get("total_work_minutes", 0),
            "total_break_minutes": schedule_plan.get("total_break_minutes", 0),
            "burnout_safety_advice": schedule_plan.get("burnout_safety_advice", ""),
            "status": "active",
            "created_at": datetime.utcnow().isoformat(),
        }
        try:
            await db["ai_work_schedules"].insert_one(schedule_doc)
        except Exception as e:
            import logging
            logging.getLogger("ai_router").error(f"Failed to auto-save schedule: {e}")

        # Attach schedule_plan + schedule_id to the API response for Flutter
        res["schedule_plan"] = schedule_plan
        res["schedule_id"] = schedule_id
    
    # Save recommendation feedback loop
    if "ai_ranking" in res:
        top_rec = res["ai_ranking"].get("top_recommendation", {})
        top_k = res["ai_ranking"].get("top_k_candidates", [])
        features_used = res["ai_ranking"].get("features_used", {})
        
        if top_rec:
            try:
                import uuid
                rec_id = str(uuid.uuid4())
                await db["ai_recommendation_logs"].insert_one({
                    "recommendation_id": rec_id,
                    "user_id": user_id,
                    "recommendation_type": top_rec.get("candidate_type", "pomodoro"),
                    "candidate": top_rec,
                    "top_k_candidates": top_k,
                    "features_used": features_used,
                    "ranking_score": top_rec.get("final_score", 0),
                    "reason_codes": top_rec.get("reason_codes", []),
                    "context_snapshot": {
                        "digital_twin_metrics": digital_twin,
                        "burnout_risk_level": burnout.get("risk_level", "LOW")
                    },
                    "timestamp": datetime.utcnow().isoformat(),
                    "shown": True,
                    "accepted": False,
                    "completed": False, 
                    "outcome": None,
                    "model_version": res.get("source") or "unknown",  # model Gemini thuc su da tra loi
                    "ranking_version": "v1-rule-based"
                })
                # Add recommendation_id to the API response for Flutter
                res["recommendation_id"] = rec_id
                res["task_type"] = top_rec.get("candidate_type", "general")
            except Exception as e:
                import logging
                logging.getLogger("ai_router").error(f"Failed to log recommendation: {e}")
            finally:
                # Remove ai_ranking from response so it doesn't clutter the frontend 
                del res["ai_ranking"]

    return res


# ============================================================
# 5. AI Work Schedule — Save & Load
# ============================================================
class SaveScheduleRequest(BaseModel):
    """Request body để lưu lịch trình do người dùng chọn."""
    schedule_id: Optional[str] = None
    target_date: str
    grade_score: float = 0
    grade_letter: str = "B"
    grade_rationale: str = ""
    schedule_blocks: List[dict] = []
    total_work_minutes: int = 0
    total_break_minutes: int = 0
    burnout_safety_advice: str = ""


@router.post("/schedule/save", summary="Lưu lịch trình AI đã tạo cho người dùng")
async def save_ai_schedule(
    req: SaveScheduleRequest,
    user_id: str = Depends(get_current_user_id),
    db: AsyncIOMotorDatabase = Depends(get_database),
):
    """
    Flutter gửi lịch trình mà người dùng đã chấp nhận lên Backend để lưu vào MongoDB.
    Nếu schedule_id đã tồn tại (auto-saved từ chat), cập nhật status → 'confirmed'.
    Nếu chưa tồn tại, tạo mới.
    """
    import uuid as _uuid

    if req.schedule_id:
        # Cập nhật trạng thái schedule đã có (auto-saved khi chat)
        result = await db["ai_work_schedules"].update_one(
            {"schedule_id": req.schedule_id, "user_id": user_id},
            {"$set": {"status": "confirmed", "confirmed_at": datetime.utcnow().isoformat()}}
        )
        if result.modified_count > 0:
            return {"status": "ok", "message": "Đã xác nhận lịch trình.", "schedule_id": req.schedule_id}

    # Tạo mới nếu chưa có
    schedule_id = str(_uuid.uuid4())
    doc = {
        "schedule_id": schedule_id,
        "user_id": user_id,
        "target_date": req.target_date,
        "grade_score": req.grade_score,
        "grade_letter": req.grade_letter,
        "grade_rationale": req.grade_rationale,
        "schedule_blocks": req.schedule_blocks,
        "total_work_minutes": req.total_work_minutes,
        "total_break_minutes": req.total_break_minutes,
        "burnout_safety_advice": req.burnout_safety_advice,
        "status": "confirmed",
        "created_at": datetime.utcnow().isoformat(),
        "confirmed_at": datetime.utcnow().isoformat(),
    }
    await db["ai_work_schedules"].insert_one(doc)
    return {"status": "ok", "message": "Đã lưu lịch trình mới.", "schedule_id": schedule_id}


@router.get("/schedule/latest", summary="Lấy lịch trình AI mới nhất đang hoạt động")
async def get_latest_schedule(
    user_id: str = Depends(get_current_user_id),
    db: AsyncIOMotorDatabase = Depends(get_database),
):
    """
    Trả về lịch trình mới nhất (active hoặc confirmed) của người dùng.
    Flutter dùng endpoint này để khôi phục lịch trình khi mở lại app.
    """
    doc = await db["ai_work_schedules"].find_one(
        {"user_id": user_id, "status": {"$in": ["active", "confirmed"]}},
        sort=[("created_at", -1)],
    )
    if not doc:
        return {"status": "empty", "message": "Chưa có lịch trình nào.", "schedule": None}

    # Remove MongoDB internal _id field (not JSON-serializable)
    doc.pop("_id", None)
    return {"status": "ok", "schedule": doc}


@router.get("/coach/daily-advice", summary="Loi khuyen AI cho hom nay")
async def daily_advice(
    user_id: str = Depends(get_current_user_id),
    db: AsyncIOMotorDatabase = Depends(get_database),
):
    """
    Phase 1: Rule-based dua tren lich su gan nhat.
    Phase 2: Thay bang Gemini API call voi context day du.
    """
    hour = now_vn().hour
    cutoff = (datetime.utcnow() - timedelta(days=3)).isoformat()
    recent = await db["productivity_logs"].find(
        {"user_id": user_id, "timestamp": {"$gte": cutoff}}
    ).to_list(length=20)

    if not recent:
        if hour < 10:
            message = ("Chao buoi sang! Day la ngay moi. "
                       "Hay bat dau voi mot phien Pomodoro 25 phut cho nhiem vu quan trong nhat.")
        elif hour < 14:
            message = "Buoi sang da qua. Hay tap trung hoan thanh 2-3 phien Pomodoro truoc khi nghi trua."
        else:
            message = "Chuc ban co buoi chieu lam viec hieu qua! Nho nghi break day du nhe."
        return {"advice": message, "source": "rule_based", "personalized": False}

    avg_score = sum(s.get("concentration_score", 50) for s in recent) / len(recent)
    skip_rate = sum(1 for s in recent if s.get("break_skipped", False)) / len(recent)
    completed_rate = sum(1 for s in recent if s.get("completed", False)) / len(recent)

    # Personalized advice
    if avg_score >= 75 and completed_rate >= 0.8:
        message = (f"Tuyet voi! Diem tap trung trung binh cua ban la {avg_score:.0f}/100. "
                   "Ban dang trong phong do dinh cao - hay tan dung thoi gian nay cho cac nhiem vu kho!")
    elif skip_rate > 0.5:
        message = (f"Ban hay bo qua break trong {skip_rate*100:.0f}% phien gan day. "
                   "Hay nho: 5 phut nghi giup nao phuc hoi va lam viec hieu qua hon!")
    elif avg_score < 40:
        message = ("Diem tap trung gan day kha thap. Thu bat dau bang nhiem vu nho, "
                   "de dien thoai xa tam tay va thiet lap muc tieu ro rang truoc moi phien.")
    else:
        message = (f"Diem tap trung trung binh: {avg_score:.0f}/100. "
                   "Ban dang di dung huong! Hay tiep tuc duy tri nhip do va nho nghi break day du.")

    return {
        "advice": message,
        "source": "rule_based",
        "personalized": True,
        "stats": {
            "avg_concentration_score": round(avg_score, 1),
            "break_skip_rate": round(skip_rate * 100, 1),
            "completion_rate": round(completed_rate * 100, 1),
        },
    }
