"""
application/ai/time_window.py
Nguồn sự thật DUY NHẤT cho mọi cửa sổ thời gian thống kê + chính sách lưu trữ 15 ngày.

Quy ước (múi giờ Asia/Ho_Chi_Minh, UTC+7; DB lưu timestamp UTC dạng ISO string):
  - today        : 00:00 hôm nay -> hiện tại
  - this_week    : Thứ Hai tuần này 00:00 -> hiện tại (tuần lịch, KHÔNG phải 7 ngày lùi)
  - last_7_days  : (hôm nay - 6 ngày) 00:00 -> hiện tại  (đủ 7 ngày gồm hôm nay)
  - last_15_days : (hôm nay - 14 ngày) 00:00 -> hiện tại (tối đa dữ liệu còn lưu)
  - Yêu cầu "30 ngày/1 tháng" bị cắt về 15 ngày (RETENTION_DAYS).
"""
from datetime import datetime, timedelta, timezone
from typing import Dict, Any, Optional

RETENTION_DAYS = 15
VN_TZ = timezone(timedelta(hours=7))
WEEKDAY_NAMES = ["Thứ Hai", "Thứ Ba", "Thứ Tư", "Thứ Năm", "Thứ Sáu", "Thứ Bảy", "Chủ Nhật"]

# Các collection có timestamp cần dọn (collection -> field thời gian)
RETENTION_COLLECTIONS = {
    "pomodoro_sessions": "synced_at",
    "productivity_logs": "timestamp",
    "daily_summaries": "date",  # định dạng YYYY-MM-DD, so sánh chuỗi vẫn đúng
}


def now_vn() -> datetime:
    return datetime.now(VN_TZ)


def _day_start(dt: datetime) -> datetime:
    return dt.replace(hour=0, minute=0, second=0, microsecond=0)


def _to_utc_iso(dt: datetime) -> str:
    """DB lưu UTC naive isoformat (datetime.utcnow().isoformat())."""
    return dt.astimezone(timezone.utc).replace(tzinfo=None).isoformat()


def get_windows(now: Optional[datetime] = None) -> Dict[str, Any]:
    now = now or now_vn()
    today0 = _day_start(now)
    monday0 = today0 - timedelta(days=now.weekday())
    days_into_week = now.weekday() + 1  # Thứ Hai = 1

    return {
        "now": now,
        "today_start": today0,
        "this_week_start": monday0,
        "last_7_days_start": today0 - timedelta(days=6),
        "last_15_days_start": today0 - timedelta(days=RETENTION_DAYS - 1),
        "days_into_week": days_into_week,
        "days_left_in_week": 7 - days_into_week,
    }


def build_time_context(now: Optional[datetime] = None) -> Dict[str, Any]:
    """Khối JSON đưa vào prompt: AI không phải tự tính ngày."""
    w = get_windows(now)
    n = w["now"]
    fmt = lambda d: d.strftime("%Y-%m-%d")
    return {
        "current_datetime": n.strftime("%Y-%m-%d %H:%M"),
        "current_date": fmt(n),
        "weekday": WEEKDAY_NAMES[n.weekday()],
        "hour": n.hour,
        "minute": n.minute,
        "timezone": "Asia/Ho_Chi_Minh",
        "week_position": {
            "days_into_week": w["days_into_week"],
            "days_left_in_week": w["days_left_in_week"],
            "phase": "dau_tuan" if w["days_into_week"] <= 2
                     else ("giua_tuan" if w["days_into_week"] <= 4 else "cuoi_tuan"),
        },
        "windows": {
            "this_week": {"from": fmt(w["this_week_start"]), "to": fmt(n),
                          "note": "Tuần lịch Thứ Hai -> Chủ Nhật; chỉ có dữ liệu tới hôm nay"},
            "last_7_days": {"from": fmt(w["last_7_days_start"]), "to": fmt(n)},
            "last_15_days": {"from": fmt(w["last_15_days_start"]), "to": fmt(n),
                             "note": f"Dữ liệu cũ hơn {RETENTION_DAYS} ngày đã bị xóa; '30 ngày/1 tháng' chỉ có tối đa 15 ngày"},
        },
        "data_retention_days": RETENTION_DAYS,
    }


def window_start_iso(name: str, now: Optional[datetime] = None) -> str:
    """Mốc bắt đầu (UTC ISO) của cửa sổ: today | this_week | last_7_days | last_15_days."""
    w = get_windows(now)
    return _to_utc_iso(w[f"{name}_start"])


async def purge_old_data(db, now: Optional[datetime] = None) -> Dict[str, int]:
    """Xóa dữ liệu cũ hơn RETENTION_DAYS ngày (tính theo ngày VN)."""
    w = get_windows(now)
    cutoff_dt = w["last_15_days_start"]
    cutoff_iso = _to_utc_iso(cutoff_dt)
    cutoff_date = cutoff_dt.strftime("%Y-%m-%d")

    deleted: Dict[str, int] = {}
    for coll, field in RETENTION_COLLECTIONS.items():
        cutoff = cutoff_date if field == "date" else cutoff_iso
        res = await db[coll].delete_many({field: {"$lt": cutoff}})
        deleted[coll] = res.deleted_count
    return deleted
