"""
application/ai/burnout_detector.py
Behavioral Burnout Risk Index (Behavioral Burnout Risk Score) cho Pomodoro AI Coach.

LƯU Ý QUAN TRỌNG VỀ TÍNH CHẤT NĂNG LỰC HỆ THỐNG:
- Đây là Behavioral Burnout Risk Score / Behavioral Burnout Risk Index dựa trên hành vi
  sử dụng hệ thống Pomodoro / Smart Watch (thời gian làm việc, thói quen nghỉ, điểm tập trung,
  tỷ lệ dở dang, gián đoạn, phiên muộn đêm).
- Đây KHÔNG PHẢI là phép đo y khoa, xác suất burnout y tế hay chẩn đoán lâm sàng.
- Dự án không lưu trữ bảng hỏi MBI-GS, PSS, ISI, POMS trực tiếp mà sử dụng các behavioral proxies
  lấy cảm hứng từ cấu trúc 3 chiều của BRIX / MBI-GS (Exhaustion, Cynicism, Low Efficacy).

NGUỒN DỮ LIỆU:
- Ưu tiên `productivity_logs` (work_min, interruptions, completed, break_skipped,
  concentration_score, hour_of_day, timestamp).
- Chỉ khi không có log mới dùng `pomodoro_sessions`.
- KHÔNG bịa dữ liệu: field thiếu => None và loại khỏi phép tính (chia lại trọng số).
- Cửa sổ phân tích: 15 ngày gần nhất.
"""
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional
from motor.motor_asyncio import AsyncIOMotorDatabase

from application.ai.time_window import window_start_iso, RETENTION_DAYS, VN_TZ

# --- Trọng số 3 chiều (lấy cảm hứng từ MBI-GS / BRIX) ---
W_EXHAUSTION = 0.40
W_CYNICISM = 0.30
W_LOW_EFFICACY = 0.30

# Hằng số tương thích bài báo / unit test cũ
CUTOFF_MODERATE = 1.50
CUTOFF_HIGH = 3.50

# --- Tham số proxy hành vi ---
DAILY_CAPACITY_MIN = 8 * 60   # 8 giờ làm/ngày = 480 phút (mức tải tiêu chuẩn)
PAUSE_SATURATION = 5.0        # >= 5 lần pause/phiên = gián đoạn cao
UNLOCK_SATURATION = 60.0      # >= 60 lần mở khóa/ngày = tương tác điện thoại cao
LATE_NIGHT_HOURS = {23, 0, 1, 2, 3, 4}
MIN_SESSIONS_FOR_CONFIDENCE = 5


def _clamp(x: float, lo: float = 0.0, hi: float = 1.0) -> float:
    return max(lo, min(hi, x))


def _num(v: Any) -> Optional[float]:
    """Ép về số; None/chuỗi rác -> None (KHÔNG tự gán giá trị mặc định bịa)."""
    try:
        return float(v) if v is not None else None
    except (TypeError, ValueError):
        return None


def _mean(vals: List[Optional[float]]) -> Optional[float]:
    xs = [v for v in vals if v is not None]
    return sum(xs) / len(xs) if xs else None


def _weighted(parts: List[Any]) -> Optional[float]:
    """Trung bình có trọng số [(w, value|None)], tự động loại phần thiếu và chia lại trọng số."""
    avail = [(w, v) for w, v in parts if v is not None]
    tw = sum(w for w, _ in avail)
    return sum(w * v for w, v in avail) / tw if tw else None


# ---------------- Chuẩn hóa bản ghi về dạng chung ----------------
def _vn_date(ts: Any) -> str:
    """timestamp/synced_at lưu ISO string -> ngày theo giờ VN (Asia/Ho_Chi_Minh, UTC+7)."""
    try:
        s = str(ts).strip()
        if not s:
            return ""
        if s.endswith("Z") or s.endswith("z"):
            s = s[:-1] + "+00:00"
        dt = datetime.fromisoformat(s)
        if dt.tzinfo is not None:
            dt = dt.astimezone(VN_TZ)
        else:
            dt = dt + timedelta(hours=7)
        return dt.strftime("%Y-%m-%d")
    except (TypeError, ValueError):
        return ""


def _from_log(d: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "date": _vn_date(d.get("timestamp")),
        "work_min": _num(d.get("work_min")),
        "pauses": _num(d.get("interruptions")),
        "completed": d.get("completed") if isinstance(d.get("completed"), bool) else None,
        "break_skipped": d.get("break_skipped") if isinstance(d.get("break_skipped"), bool) else None,
        "focus": _num(d.get("concentration_score")),
        "hour": _num(d.get("hour_of_day")),
        "unlocks": None,
    }


def _from_session(d: Dict[str, Any]) -> Dict[str, Any]:
    hw = d.get("hardware_data") or {}
    ph = d.get("phone_data") or {}
    cp = d.get("computed") or {}
    return {
        "date": _vn_date(d.get("synced_at")),
        "work_min": _num(hw.get("work_min")),
        "pauses": _num(hw.get("pauses")),
        "completed": hw.get("completed") if isinstance(hw.get("completed"), bool) else None,
        "break_skipped": None,  # field break_skipped không có ở pomodoro_sessions cũ
        "focus": _num(cp.get("concentration_score")),
        "hour": _num(cp.get("hour_of_day")),
        "unlocks": _num(ph.get("unlock_count")),
    }


# ---------------- 3 chiều Behavioral Proxies (mỗi chiều thang 0-6) ----------------
def _exhaustion(avg_daily_work_min: Optional[float], skip_rate: Optional[float]) -> Optional[float]:
    """
    Behavioral Exhaustion Proxy: Tải làm việc KẾT HỢP với dấu hiệu phục hồi kém (bỏ giải lao).
    Lưu ý: Làm việc 8h (480m) nhưng tập trung tốt, nghỉ giải lao đầy đủ KHÔNG bị đánh giá kiệt sức.
    """
    if avg_daily_work_min is None and skip_rate is None:
        return None

    load = None if avg_daily_work_min is None else _clamp(avg_daily_work_min / DAILY_CAPACITY_MIN)

    if load is not None and skip_rate is not None:
        # Tải cao kết hợp phục hồi kém (skip_rate cao) mới làm tăng nhanh exhaustion
        ex_val = load * (0.25 + 0.75 * skip_rate)
    elif load is not None:
        ex_val = load * 0.35
    else:
        ex_val = skip_rate * 0.70

    return 6.0 * _clamp(ex_val)


def _cynicism(avg_pauses: Optional[float], incomplete_rate: Optional[float],
              unlocks_per_day: Optional[float]) -> Optional[float]:
    """
    Behavioral Cynicism / Disengagement Proxy: Thờ ơ, ngắt quãng liên tục, bỏ dở phiên.
    Số lần mở khóa điện thoại chỉ là 1 tín hiệu gián tiếp. Nếu thiếu unlocks => tự chia lại trọng số.
    """
    pause_n = None if avg_pauses is None else _clamp(avg_pauses / PAUSE_SATURATION)
    unlock_n = None if unlocks_per_day is None else _clamp(unlocks_per_day / UNLOCK_SATURATION)
    v = _weighted([(0.40, pause_n), (0.40, incomplete_rate), (0.20, unlock_n)])
    return None if v is None else 6.0 * _clamp(v)


def _low_efficacy(avg_focus: Optional[float]) -> Optional[float]:
    """
    Behavioral Low Efficacy Proxy: Điểm tập trung trung bình trong cửa sổ 15 ngày bị suy giảm.
    Sử dụng trung bình cửa sổ dữ liệu để tránh 1-2 phiên tụt tập trung làm nhầm lẫn risk.
    """
    return None if avg_focus is None else 6.0 * (1.0 - _clamp(avg_focus / 100.0))


# ---------------- Bounded Contextual Modifiers (Tín hiệu ngữ cảnh có giới hạn) ----------------
def _factor_behavioral_stress(avg_pauses: Optional[float], incomplete_rate: Optional[float]) -> float:
    """Proxy mức độ căng thẳng hành vi từ tỷ lệ ngắt quãng và bỏ dở."""
    pause_n = None if avg_pauses is None else _clamp(avg_pauses / PAUSE_SATURATION)
    stress_proxy = _weighted([(0.5, pause_n), (0.5, incomplete_rate)])
    if stress_proxy is None or stress_proxy < 0.30:
        return 1.0
    return 1.05 if stress_proxy < 0.50 else 1.10


def _factor_late_night_work(late_night_ratio: Optional[float]) -> float:
    """Tín hiệu làm việc muộn đêm (23h-5h) liên quan đến nguy cơ suy giảm phục hồi."""
    if late_night_ratio is None or late_night_ratio < 0.10:
        return 1.0
    return 1.05 if late_night_ratio < 0.30 else 1.10


def _factor_behavioral_mood(avg_focus: Optional[float], incomplete_rate: Optional[float],
                            avg_pauses: Optional[float], load: Optional[float]) -> float:
    """Tỷ lệ giữa động lực tập trung (positive engagement) và ma sát hành vi (friction)."""
    if avg_focus is None:
        return 1.0
    pa = _clamp(avg_focus / 100.0)
    pause_n = _clamp((avg_pauses or 0.0) / PAUSE_SATURATION)
    na = 0.4 * (incomplete_rate or 0.0) + 0.4 * pause_n + 0.2 * (load or 0.0)
    ratio = pa / max(na, 0.05)
    if ratio >= 2.5:
        return 0.92  # Giảm rủi ro khi tập trung cao, ít ngắt quãng
    elif ratio >= 1.5:
        return 0.97
    elif ratio >= 0.8:
        return 1.03
    return 1.08


def _build_signals(avg_daily_work: Optional[float], skip_rate: Optional[float],
                   avg_focus: Optional[float], incomplete_rate: Optional[float],
                   avg_pauses: Optional[float], late_ratio: Optional[float]) -> Dict[str, str]:
    """Tạo đối tượng tín hiệu giải thích được (Explainable Output Signals)."""
    # Workload
    if avg_daily_work is None:
        workload = "unknown"
    elif avg_daily_work < 240:
        workload = "low"
    elif avg_daily_work < 450:
        workload = "moderate"
    else:
        workload = "high"

    # Recovery
    if skip_rate is None:
        recovery = "unknown"
    elif skip_rate < 0.15:
        recovery = "good"
    elif skip_rate < 0.40:
        recovery = "moderate"
    else:
        recovery = "poor"

    # Focus
    if avg_focus is None:
        focus = "unknown"
    elif avg_focus >= 75:
        focus = "high"
    elif avg_focus >= 50:
        focus = "moderate"
    else:
        focus = "low"

    # Completion
    if incomplete_rate is None:
        completion = "unknown"
    elif incomplete_rate < 0.15:
        completion = "high"
    elif incomplete_rate < 0.35:
        completion = "moderate"
    else:
        completion = "low"

    # Interruptions
    if avg_pauses is None:
        interruptions = "unknown"
    elif avg_pauses < 2.0:
        interruptions = "low"
    elif avg_pauses < 3.5:
        interruptions = "moderate"
    else:
        interruptions = "high"

    # Late Night Work
    if late_ratio is None:
        late_night = "unknown"
    elif late_ratio < 0.10:
        late_night = "low"
    elif late_ratio < 0.25:
        late_night = "moderate"
    else:
        late_night = "high"

    return {
        "workload": workload,
        "recovery": recovery,
        "focus": focus,
        "completion": completion,
        "interruptions": interruptions,
        "late_night_work": late_night,
    }


def _empty() -> Dict[str, Any]:
    return {
        "burnout_risk_score": 0.0,
        "risk_level": "LOW",
        "brix_o": 0.0,
        "brix_w": 0.0,
        "data_confidence": "none",
        "data_source": None,
        "subscales_0_6": {"exhaustion": None, "cynicism": None, "low_efficacy": None},
        "weight_factors": {"stress": 1.0, "insomnia": 1.0, "mood": 1.0},
        "factors": {
            "sessions_analyzed": 0,
            "active_days": 0,
            "window_days": RETENTION_DAYS,
            "avg_daily_work_min": None,
            "skipped_break_rate": None,
            "avg_pauses_per_session": None,
            "incomplete_rate": None,
            "avg_focus": None,
            "late_night_ratio": None,
            "unlocks_per_day": None,
        },
        "signals": {
            "workload": "unknown",
            "recovery": "unknown",
            "focus": "unknown",
            "completion": "unknown",
            "interruptions": "unknown",
            "late_night_work": "unknown",
        },
    }


def compute_brix(sessions: List[Dict[str, Any]], logs: List[Dict[str, Any]],
                 unlocks_per_day: Optional[float] = None) -> Dict[str, Any]:
    """
    Hàm thuần tính toán Behavioral Burnout Risk Score / Index.
    Ưu tiên `logs`; không có log mới dùng `sessions`.
    """
    if logs:
        recs, source = [_from_log(d) for d in logs], "productivity_logs"
    elif sessions:
        recs, source = [_from_session(d) for d in sessions], "pomodoro_sessions"
    else:
        return _empty()

    n = len(recs)
    work_vals = [r["work_min"] for r in recs if r["work_min"] is not None]
    active_days = len({r["date"] for r in recs if r["date"]})
    avg_daily_work = (sum(work_vals) / active_days) if (work_vals and active_days) else None

    br = [r["break_skipped"] for r in recs if r["break_skipped"] is not None]
    skip_rate = (sum(1 for b in br if b) / len(br)) if br else None
    avg_pauses = _mean([r["pauses"] for r in recs])
    cp = [r["completed"] for r in recs if r["completed"] is not None]
    incomplete_rate = (sum(1 for c in cp if not c) / len(cp)) if cp else None
    avg_focus = _mean([r["focus"] for r in recs])

    hours = [int(r["hour"]) for r in recs if r["hour"] is not None and 0 <= r["hour"] <= 23]
    late_ratio = (sum(1 for h in hours if h in LATE_NIGHT_HOURS) / len(hours)) if hours else None

    if unlocks_per_day is None:
        unlocks_per_day = _mean([r["unlocks"] for r in recs])  # chỉ có ở nguồn sessions

    load = None if avg_daily_work is None else _clamp(avg_daily_work / DAILY_CAPACITY_MIN)

    # 1. 3 subscales (thang 0-6)
    ex = _exhaustion(avg_daily_work, skip_rate)
    cy = _cynicism(avg_pauses, incomplete_rate, unlocks_per_day)
    pe = _low_efficacy(avg_focus)

    # 2. Base Index (brix_o): Tổng hợp có trọng số
    dims = _weighted([(W_EXHAUSTION, ex), (W_CYNICISM, cy), (W_LOW_EFFICACY, pe)])
    if dims is None:
        out = _empty()
        out["data_confidence"] = "none" if n == 0 else "low"
        out["factors"]["sessions_analyzed"] = n
        out["factors"]["active_days"] = active_days
        return out

    brix_o = dims

    # 3. Contextual Bounded Modifiers
    f_s = _factor_behavioral_stress(avg_pauses, incomplete_rate)
    f_i = _factor_late_night_work(late_ratio)
    f_m = _factor_behavioral_mood(avg_focus, incomplete_rate, avg_pauses, load)

    raw_modifier = f_s * f_i * f_m
    total_modifier = _clamp(raw_modifier, lo=0.88, hi=1.20)
    brix_w = brix_o * total_modifier

    # 4. Final Score (0-100) & Operational Risk Level Thresholds
    score = round(_clamp(brix_w / 6.0) * 100.0, 1)

    # Operational thresholds của AI Coach safety policy
    if score >= 70.0:
        level = "CRITICAL"
    elif score >= 50.0:
        level = "HIGH"
    elif score >= 30.0:
        level = "MODERATE"
    else:
        level = "LOW"

    confidence = "ok" if n >= MIN_SESSIONS_FOR_CONFIDENCE else "low"
    r2 = lambda v: None if v is None else round(v, 2)

    return {
        "burnout_risk_score": score,
        "risk_level": level,
        "brix_o": round(brix_o, 2),
        "brix_w": round(brix_w, 2),
        "data_confidence": confidence,
        "data_source": source,
        "subscales_0_6": {
            "exhaustion": r2(ex),
            "cynicism": r2(cy),
            "low_efficacy": r2(pe)
        },
        "weight_factors": {
            "stress": round(f_s, 2),
            "insomnia": round(f_i, 2),
            "mood": round(f_m, 2)
        },
        "factors": {
            "sessions_analyzed": n,
            "active_days": active_days,
            "window_days": RETENTION_DAYS,
            "avg_daily_work_min": None if avg_daily_work is None else round(avg_daily_work, 1),
            "skipped_break_rate": r2(skip_rate),
            "avg_pauses_per_session": r2(avg_pauses),
            "incomplete_rate": r2(incomplete_rate),
            "avg_focus": None if avg_focus is None else round(avg_focus, 1),
            "late_night_ratio": r2(late_ratio),
            "unlocks_per_day": r2(unlocks_per_day),
        },
        "signals": _build_signals(
            avg_daily_work=avg_daily_work,
            skip_rate=skip_rate,
            avg_focus=avg_focus,
            incomplete_rate=incomplete_rate,
            avg_pauses=avg_pauses,
            late_ratio=late_ratio
        )
    }


class BurnoutDetector:
    def __init__(self, db: AsyncIOMotorDatabase):
        self.db = db

    async def _real_unlocks_per_day(self, user_id: str) -> Optional[float]:
        """Số lần mở khóa điện thoại/ngày THẬT từ daily_summaries trong cửa sổ 15 ngày."""
        from_date = (datetime.now(VN_TZ) - timedelta(days=RETENTION_DAYS - 1)).strftime("%Y-%m-%d")
        rows = await self.db["daily_summaries"].find(
            {"user_id": user_id, "date": {"$gte": from_date}}, {"total_unlocks": 1}
        ).to_list(length=RETENTION_DAYS + 1)
        vals = [_num(r.get("total_unlocks")) for r in rows]
        return _mean(vals)

    async def calculate_burnout_risk(self, user_id: str) -> Dict[str, Any]:
        since = window_start_iso("last_15_days")
        logs = await self.db["productivity_logs"].find(
            {"user_id": user_id, "timestamp": {"$gte": since}}
        ).to_list(length=1000)
        sessions = await self.db["pomodoro_sessions"].find(
            {"user_id": user_id, "synced_at": {"$gte": since}}
        ).to_list(length=1000)
        return compute_brix(sessions, logs, await self._real_unlocks_per_day(user_id))
