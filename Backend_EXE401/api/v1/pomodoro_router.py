"""
api/v1/pomodoro_router.py - Tang API Controller cho luong Pomodoro Sync
Nhan du lieu tu App Flutter -> Phan tich AI -> Tra ve feedback
"""
from fastapi import APIRouter, Depends, HTTPException, status
from motor.motor_asyncio import AsyncIOMotorDatabase
from pydantic import BaseModel
from datetime import datetime
from typing import Optional

from core.database import get_database
from core.security import get_current_user_id

router = APIRouter()


# ============================================================
# Pydantic Schemas - Validate payload tu Flutter App
# ============================================================
class HardwareData(BaseModel):
    work_min: int = 25
    break_min: int = 5
    pauses: int = 0
    completed: bool = False
    session_count: int = 0
    start_time: Optional[str] = None     # ISO format tu RTC DS3231
    end_time: Optional[str] = None       # ISO format tu RTC DS3231
    temperature: Optional[int] = None    # Nhiet do tu DS3231 (°C)


class PhoneData(BaseModel):
    unlock_count: int = 0
    task_type: str = "general"           # coding/reading/meeting/exercise/general
    recommendation_id: Optional[str] = None
    timestamp: Optional[str] = None


class PomodoroSyncPayload(BaseModel):
    user_id: str
    session_id: Optional[str] = None     # Dinh danh phien tu ESP32/Flutter (Idempotency Key)
    hardware_data: HardwareData
    phone_data: PhoneData


# ============================================================
# AI Feedback Engine (Rule-based -> co the nang len LLM sau)
# ============================================================
def generate_ai_feedback(
    payload: PomodoroSyncPayload,
    actual_work_secs: int = 0,
    comp_rate: float = 0.0,
    conc_score: float = 0.0,
) -> str:
    """
    Phan tich hanh vi tap trung va tra ve loi khuyen ca nhan hoa.
    Dua tren THOI GIAN THUC TE (actual_work_secs) va TY LE HOAN THANH (comp_rate)
    de danh gia chinh xac, khong "khen ao".
    """
    hw = payload.hardware_data
    ph = payload.phone_data
    pauses = hw.pauses
    unlocks = ph.unlock_count
    completed = hw.completed
    work_min = hw.work_min
    actual_min = actual_work_secs / 60.0  # Thoi gian thuc tinh bang phut

    # === PHIEN BO CUOC / CHUA HOAN THANH ===
    if not completed:
        # Bo cuoc qua som (duoi 3 phut)
        if actual_min < 3:
            return (
                f"Ban chi hoc duoc {actual_min:.1f} phut trong phien {work_min} phut "
                f"(hoan thanh {comp_rate:.0f}%). Diem tap trung: {conc_score:.0f}/100. "
                "Day la ket qua RAT TE! Hay thu hit tho sau, dat dien thoai xuong "
                "va quay lai ban lam viec. Muc tieu: hoan thanh toi thieu 50% phien!"
            )
        # Bo cuoc nua chung (3-70%)
        elif comp_rate < 70:
            return (
                f"Ban dung phien sau {actual_min:.1f}/{work_min} phut "
                f"(hoan thanh {comp_rate:.0f}%, {pauses} lan pause). "
                f"Diem tap trung: {conc_score:.0f}/100. "
                "Chua dat yeu cau! Lan sau co gang hoan thanh tron ven nhe."
            )
        # Gan hoan thanh nhung bo cuoc (>70%)
        else:
            return (
                f"Ban da lam duoc {actual_min:.1f}/{work_min} phut "
                f"(hoan thanh {comp_rate:.0f}%). Diem: {conc_score:.0f}/100. "
                "Thieu mot chut nua la hoan thanh! Lan sau co len nhe!"
            )

    # === PHIEN HOAN THANH ===
    total_distractions = pauses + unlocks

    if total_distractions == 0:
        return (
            f"TUYET VOI! Phien {work_min} phut hoan thanh HOAN HAO "
            f"khong xao nhang. Diem: {conc_score:.0f}/100. "
            "Tiep tuc phong do xuat sac nay!"
        )
    elif pauses >= 3 and unlocks >= 3:
        return (
            f"Phien {work_min} phut co {pauses} lan pause va {unlocks} lan mo khoa dien thoai. "
            f"Diem: {conc_score:.0f}/100. "
            "Dat dien thoai xa tam tay va bat che do may bay!"
        )
    elif unlocks >= 3:
        return (
            f"Ban mo khoa dien thoai {unlocks} lan trong phien. "
            f"Diem: {conc_score:.0f}/100. "
            "Dien thoai dang la ke thu so 1! Bat che do 'Khong lam phien'!"
        )
    elif pauses >= 3:
        return (
            f"Ban tam dung {pauses} lan trong phien {work_min} phut. "
            f"Diem: {conc_score:.0f}/100. "
            "Uong nuoc, di ve sinh TRUOC khi bat dau phien!"
        )
    else:
        return (
            f"Tot lam! Phien {work_min} phut hoan thanh voi {total_distractions} "
            f"lan xao nhang nho. Diem: {conc_score:.0f}/100. Duy tri nhe!"
        )


# ============================================================
# Helpers: Multi-Tenant Scoped Session ID
# ============================================================
def generate_scoped_session_id(user_id: str, raw_session_id: str) -> str:
    """
    Sinh session_id co pham vi theo user (multi-tenant scoped key).
    Dam bao tinh duy nhat giua cac user ngay ca khi 2 thiet bi ESP32 sinh cung session_id,
    dong thoi tuong thich 100% voi unique index toan cuc 'uniq_pomodoro_session_id' tren MongoDB.
    """
    raw = str(raw_session_id).strip()
    user_prefix = f"pomo_{user_id}_"
    if raw.startswith(user_prefix):
        return raw
    if raw.startswith(f"{user_id}_"):
        return f"pomo_{raw}"
    if raw.startswith("pomo_"):
        return f"pomo_{user_id}_{raw[5:]}"
    return f"pomo_{user_id}_{raw}"


# ============================================================
# Endpoints
# ============================================================
@router.post("/sync", summary="Dong bo du lieu Pomodoro tu ESP32 qua App")
async def sync_pomodoro_session(
    payload: PomodoroSyncPayload,
    user_id: str = Depends(get_current_user_id),
    db: AsyncIOMotorDatabase = Depends(get_database),
):
    """
    Nhan du lieu phien Pomodoro tu App Flutter, luu MongoDB, tra ve AI feedback.
    Bao gom: hardware_data (tu ESP32) + phone_data (tu App) + computed (Backend tinh).
    Multi-tenant isolated: user_id duoc trich xuat tu token xac thuc backend,
    khong tin tuong user_id tu client.
    """
    payload.user_id = user_id
    auth_user_id = user_id
    hw = payload.hardware_data
    ph = payload.phone_data

    # === Tinh computed fields ===
    now_utc = datetime.utcnow()

    # Parse start_time va end_time
    try:
        start_dt = datetime.fromisoformat(hw.start_time) if hw.start_time else now_utc
    except (ValueError, TypeError):
        start_dt = now_utc
    try:
        end_dt = datetime.fromisoformat(hw.end_time) if hw.end_time else now_utc
    except (ValueError, TypeError):
        end_dt = now_utc

    actual_work_secs = max(0, int((end_dt - start_dt).total_seconds()))
    hour_of_day = start_dt.hour
    day_of_week = start_dt.weekday()  # 0=Monday..6=Sunday

    # % hoan thanh (tinh TRUOC de dung cho concentration_score)
    if hw.completed:
        comp_rate = 100.0
    elif actual_work_secs > 0 and hw.work_min > 0:
        comp_rate = min(100.0, (actual_work_secs / (hw.work_min * 60)) * 100.0)
    else:
        comp_rate = 0.0

    # === DIEM TAP TRUNG (HARDCORE) ===
    # Buoc 1: Diem chat luong (tru diem theo xao nhang)
    distraction_penalty = (hw.pauses * 5.0) + (ph.unlock_count * 10.0)
    quality_score = max(0.0, 100.0 - distraction_penalty)
    # Buoc 2: Nhan voi ty le hoan thanh -> Hoc 1 phut = diem cuc thap
    conc_score = round(quality_score * (comp_rate / 100.0), 1)

    # Phan tich AI feedback (SAU KHI da tinh xong actual_work_secs, comp_rate, conc_score)
    feedback = generate_ai_feedback(
        payload,
        actual_work_secs=actual_work_secs,
        comp_rate=comp_rate,
        conc_score=conc_score,
    )

    # Xac dinh buoi
    is_morning = 5 <= hour_of_day < 12
    is_afternoon = 12 <= hour_of_day < 18

    computed = {
        "actual_work_secs": actual_work_secs,
        "concentration_score": round(conc_score, 1),
        "completion_rate": round(comp_rate, 1),
        "hour_of_day": hour_of_day,
        "day_of_week": day_of_week,
        "is_morning": is_morning,
        "is_afternoon": is_afternoon,
    }

    # === Xac dinh khoa dinh danh phien (Multi-Tenant Idempotency Key) ===
    # Uu tien session_id on dinh tu ESP32 / Flutter, hoac fallback ve khoa tu nhien hop le
    raw_session_id = payload.session_id or f"pomo_{hw.start_time or now_utc.isoformat()}_{hw.session_count}"
    scoped_session_id = generate_scoped_session_id(auth_user_id, raw_session_id)

    # === Luu vao MongoDB (Atomic Upsert theo cap user_id va session_id) ===
    document = {
        "user_id": auth_user_id,
        "session_id": scoped_session_id,
        "hardware_session_id": raw_session_id,
        "hardware_data": hw.model_dump(),
        "phone_data": ph.model_dump(),
        "computed": computed,
        "ai_feedback": feedback,
        "synced_at": now_utc.isoformat(),
    }

    # Thao tac nguyen tu voi update_one(..., upsert=True) de chong ghi trung va va cham multi-tenant
    is_new = False
    session_doc_id = None
    upsert_error: Optional[Exception] = None
    try:
        upsert_res = await db["pomodoro_sessions"].update_one(
            {"user_id": auth_user_id, "session_id": scoped_session_id},
            {"$setOnInsert": document},
            upsert=True
        )
        if upsert_res.upserted_id is not None:
            is_new = True
            session_doc_id = str(upsert_res.upserted_id)
        else:
            is_new = False
    except Exception as e:
        # Co the do race condition, xung dot duplicate key, hoac loi ket noi/ghi DB
        is_new = False
        upsert_error = e

    if not is_new:
        # Xac minh xem phien da thuc su ton tai truoc do cua DUNG user nay (Retry / Idempotency)
        try:
            existing_doc = await db["pomodoro_sessions"].find_one({
                "user_id": auth_user_id,
                "$or": [
                    {"session_id": scoped_session_id},
                    {"session_id": raw_session_id},
                    {"hardware_session_id": raw_session_id},
                ]
            })
        except Exception as find_err:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=f"Loi ket noi co so du lieu khi xac minh phien: {find_err}"
            )

        if existing_doc:
            # Multi-tenant safety check: tuyet doi khong tra ve du lieu neu khong thuoc user nay
            if existing_doc.get("user_id") != auth_user_id:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Khong co quyen truy cap phien Pomodoro cua nguoi dung khac"
                )
            session_doc_id = str(existing_doc.get("_id"))
            feedback = existing_doc.get("ai_feedback", feedback)
            computed = existing_doc.get("computed", computed)
        else:
            # Kiem tra xem co phai bi va cham duplicate key voi user khac tren index toan cuc khong
            other_user_doc = None
            try:
                other_user_doc = await db["pomodoro_sessions"].find_one({
                    "$or": [
                        {"session_id": raw_session_id},
                        {"session_id": scoped_session_id},
                    ]
                })
            except Exception:
                pass

            if other_user_doc and other_user_doc.get("user_id") != auth_user_id:
                # Tuyet doi khong tra du lieu nguoi khac hoac coi day la retry hop le!
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Xung dot session_id voi nguoi dung khac ({raw_session_id}). Khong the su dung session_id nay."
                )

            # Document khong he ton tai trong DB: thao tac ghi that bai va khong tim thay ban ghi hop le
            # Nhat quyet KHONG tra HTTP 200 gia mao vi se khien Flutter ACK va ESP32 xoa mat phien!
            err_msg = str(upsert_error) if upsert_error else "Khong the luu va khong tim thay ban ghi tuong ung"
            status_code = status.HTTP_503_SERVICE_UNAVAILABLE if (upsert_error and "timeout" in err_msg.lower()) else status.HTTP_500_INTERNAL_SERVER_ERROR
            raise HTTPException(
                status_code=status_code,
                detail=f"Loi ghi du lieu MongoDB cho phien Pomodoro ({raw_session_id}): {err_msg}"
            )

    # === Chi ghi log va huan luyen AI khi phien la MOI (tranh huan luyen duplicate) ===
    if is_new and session_doc_id:
        prod_log = {
            "user_id": auth_user_id,
            "session_id": session_doc_id,
            "recommendation_id": ph.recommendation_id,
            "work_min": hw.work_min,
            "break_min": hw.break_min,
            "concentration_score": conc_score,
            "completion_rate": comp_rate,
            "interruptions": hw.pauses,
            "break_skipped": False,
            "task_type": ph.task_type,
            "completed": hw.completed,
            "timestamp": now_utc.isoformat(),
            "hour_of_day": hour_of_day,
            "day_of_week": day_of_week,
        }
        try:
            await db["productivity_logs"].update_one(
                {"user_id": auth_user_id, "session_id": session_doc_id},
                {"$setOnInsert": prod_log},
                upsert=True
            )
        except Exception:
            pass

        # === Cap nhat AI Recommendation Log (feedback loop) ===
        if ph.recommendation_id:
            try:
                from application.ai.adaptive_pomodoro_agent import AdaptivePomodoroAgent
                from domain.entities.productivity_entity import SessionFeedback

                sf = SessionFeedback(
                    user_id=auth_user_id,
                    session_id=session_doc_id,
                    recommendation_id=ph.recommendation_id,
                    work_min=hw.work_min,
                    break_min=hw.break_min,
                    concentration_score=conc_score,
                    completion_rate=comp_rate,
                    interruptions=hw.pauses,
                    break_skipped=False,
                    task_type=ph.task_type,
                    hour_of_day=hour_of_day,
                    day_of_week=day_of_week,
                )
                agent = AdaptivePomodoroAgent(user_id=auth_user_id, db=db)
                await agent.update(sf)
            except Exception as e:
                print(f"[WARN] AI feedback loop error: {e}")

    return {
        "status": "ok",
        "session_id": session_doc_id,
        "feedback": feedback,
        "computed": computed,
        "summary": {
            "work_min": hw.work_min,
            "completed": hw.completed,
            "total_distractions": hw.pauses + ph.unlock_count,
            "start_time": hw.start_time,
            "end_time": hw.end_time,
            "task_type": ph.task_type,
        },
    }


@router.get("/history/{user_id}", summary="Lich su phien Pomodoro cua user")
async def get_pomodoro_history(
    user_id: str,
    limit: int = 10,
    current_user_id: str = Depends(get_current_user_id),
    db: AsyncIOMotorDatabase = Depends(get_database),
):
    """Lay {limit} phien gan nhat cua user. Chi chinh chu moi co quyen xem."""
    if user_id != current_user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Khong co quyen xem lich su cua nguoi dung khac"
        )
    cursor = (
        db["pomodoro_sessions"]
        .find({"user_id": user_id}, {"_id": 0})
        .sort("synced_at", -1)
        .limit(limit)
    )
    sessions = await cursor.to_list(length=limit)
    return {"user_id": user_id, "sessions": sessions}
