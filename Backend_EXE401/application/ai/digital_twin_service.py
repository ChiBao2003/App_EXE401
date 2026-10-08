"""
application/ai/digital_twin_service.py
Calculates Digital Twin profile metrics (Focus, Break, Stress, Efficiency)
by aggregating user Pomodoro session logs over the last 15 days (retention limit).
"""
from typing import Dict, Any, List
from datetime import datetime, timedelta
from motor.motor_asyncio import AsyncIOMotorDatabase
from application.ai.time_window import window_start_iso


class DigitalTwinService:
    def __init__(self, db: AsyncIOMotorDatabase):
        self.db = db

    async def compute_profile(self, user_id: str) -> Dict[str, Any]:
        since_iso = window_start_iso("last_15_days")
        cursor = self.db["pomodoro_sessions"].find({
            "user_id": user_id,
            "synced_at": {"$gte": since_iso}
        })
        sessions = await cursor.to_list(length=200)

        if not sessions:
            # Chưa có phiên thật: KHÔNG bịa số mặc định. Tầng trên phải nói "chưa có dữ liệu".
            return {
                "focus_score": None,
                "break_score": None,
                "stress_level": None,
                "efficiency": None,
                "total_sessions": 0,
                "data_confidence": "none",
                "today_sessions_detail": [],
                "today_productivity_logs": []
            }

        # ── Aggregate chỉ dùng giá trị THẬT, bỏ qua bản ghi thiếu field ──
        work_vals = [s.get("hardware_data", {}).get("work_min")
                     for s in sessions
                     if s.get("hardware_data", {}).get("work_min") is not None]
        pause_vals = [s.get("hardware_data", {}).get("pauses", 0) for s in sessions]
        # completed mặc định False (an toàn hơn True) khi field thiếu
        completed = sum(1 for s in sessions
                        if s.get("hardware_data", {}).get("completed", False))

        n = len(sessions)
        total_work = sum(work_vals) if work_vals else 0
        avg_pauses = sum(pause_vals) / n if n > 0 else 0
        completion_rate = (completed / n) * 100 if n > 0 else 0
        focus_score = max(0.0, min(100.0, completion_rate - (avg_pauses * 3.5)))
        stress_level = max(0.0, min(100.0, (avg_pauses * 8.0) + (100 - completion_rate) * 0.4))
        break_score = max(20.0, 100.0 - (stress_level * 0.5))
        efficiency = (focus_score * 0.6) + (completion_rate * 0.4)

        # 2. Extract Task-Type Specific Performance from productivity_logs
        cursor_tasks = self.db["productivity_logs"].find({
            "user_id": user_id,
            "timestamp": {"$gte": since_iso}
        })
        task_logs = await cursor_tasks.to_list(length=500)

        # Thống kê theo từng cửa sổ thời gian (this_week = tuần lịch từ Thứ Hai)
        period_stats = {}
        for name in ("today", "this_week", "last_7_days", "last_15_days"):
            start = window_start_iso(name)
            in_win = [l for l in task_logs if str(l.get("timestamp", "")) >= start]
            cnt = len(in_win)
            period_stats[name] = {
                "session_count": cnt,
                "total_work_min": sum(l.get("work_min", 0) for l in in_win),
                "avg_focus": round(
                    sum(l.get("concentration_score", 0) for l in in_win if l.get("concentration_score") is not None)
                    / max(1, sum(1 for l in in_win if l.get("concentration_score") is not None)), 1
                ) if any(l.get("concentration_score") is not None for l in in_win) else None,
            }

        task_performance = {}
        for log in task_logs:
            t_type = log.get("task_type", "general")
            if t_type not in task_performance:
                task_performance[t_type] = {
                    "sessions": 0,
                    "focus_sum": 0.0,
                    "morning_sessions": 0,
                    "morning_focus_sum": 0.0,
                    "afternoon_sessions": 0,
                    "afternoon_focus_sum": 0.0,
                }
            
            p = task_performance[t_type]
            p["sessions"] += 1
            focus = log.get("concentration_score")
            if focus is not None:
                p["focus_sum"] += focus
            else:
                p["sessions"] -= 1  # Không tính phiên thiếu focus vào count
                continue

            hour = log.get("hour_of_day")
            if hour is None:
                continue
            if 5 <= hour < 12:
                p["morning_sessions"] += 1
                p["morning_focus_sum"] += focus
            elif 12 <= hour < 18:
                p["afternoon_sessions"] += 1
                p["afternoon_focus_sum"] += focus

        # Aggregate averages
        task_stats = {}
        for t_type, p in task_performance.items():
            task_stats[t_type] = {
                "session_count": p["sessions"],
                "avg_focus": p["focus_sum"] / p["sessions"] if p["sessions"] > 0 else 50.0,
                "morning_focus": p["morning_focus_sum"] / p["morning_sessions"] if p["morning_sessions"] > 0 else None,
                "afternoon_focus": p["afternoon_focus_sum"] / p["afternoon_sessions"] if p["afternoon_sessions"] > 0 else None,
            }

        # 3. Fetch TODAY's detailed sessions for AI to answer specific questions
        today_sessions_detail = await self._get_today_sessions(user_id)
        today_productivity_logs = await self._get_today_productivity_logs(user_id)

        return {
            "focus_score": round(focus_score, 1),
            "break_score": round(break_score, 1),
            "stress_level": round(stress_level, 1),
            "efficiency": round(efficiency, 1),
            "total_sessions": len(sessions),
            "task_performance": task_stats,
            "period_stats": period_stats,
            "today_sessions_detail": today_sessions_detail,
            "today_productivity_logs": today_productivity_logs
        }

    async def _get_today_sessions(self, user_id: str) -> List[Dict[str, Any]]:
        """Lấy danh sách chi tiết từng phiên Pomodoro hôm nay."""
        today_iso = window_start_iso("today")
        cursor = self.db["pomodoro_sessions"].find(
            {
                "user_id": user_id,
                "synced_at": {"$gte": today_iso}
            },
            {"_id": 0}
        ).sort("synced_at", 1)
        sessions = await cursor.to_list(length=50)

        result = []
        for i, s in enumerate(sessions, 1):
            hw = s.get("hardware_data", {})
            ph = s.get("phone_data", {})
            comp = s.get("computed", {})
            result.append({
                "stt": i,
                "start_time": hw.get("start_time", ""),
                "end_time": hw.get("end_time", ""),
                "work_min": hw.get("work_min", 25),
                "break_min": hw.get("break_min", 5),
                "pauses": hw.get("pauses", 0),
                "completed": hw.get("completed", False),
                "task_type": ph.get("task_type", "general"),
                "temperature": hw.get("temperature"),
                "actual_work_secs": comp.get("actual_work_secs", 0),
                "concentration_score": comp.get("concentration_score", 0),
                "completion_rate": comp.get("completion_rate", 0),
                "ai_feedback": s.get("ai_feedback", ""),
            })
        return result

    async def _get_today_productivity_logs(self, user_id: str) -> List[Dict[str, Any]]:
        """Lấy danh sách chi tiết productivity logs hôm nay."""
        today_iso = window_start_iso("today")
        cursor = self.db["productivity_logs"].find(
            {
                "user_id": user_id,
                "timestamp": {"$gte": today_iso}
            },
            {"_id": 0}
        ).sort("timestamp", 1)
        logs = await cursor.to_list(length=50)

        result = []
        for i, log in enumerate(logs, 1):
            result.append({
                "stt": i,
                "thoi_gian": log.get("timestamp", ""),
                "task_type": log.get("task_type", "general"),
                "work_min": log.get("work_min", 25),
                "break_min": log.get("break_min", 5),
                "concentration_score": log.get("concentration_score", 50),
                "completion_rate": log.get("completion_rate", 0),
                "interruptions": log.get("interruptions", 0),
                "break_skipped": log.get("break_skipped", False),
                "hour_of_day": log.get("hour_of_day", 0),
            })
        return result

