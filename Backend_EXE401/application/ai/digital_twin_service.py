"""
application/ai/digital_twin_service.py
Calculates Digital Twin profile metrics (Focus, Break, Stress, Efficiency)
by aggregating user Pomodoro session logs over 30 days.
"""
from typing import Dict, Any, List
from datetime import datetime, timedelta
from motor.motor_asyncio import AsyncIOMotorDatabase


class DigitalTwinService:
    def __init__(self, db: AsyncIOMotorDatabase):
        self.db = db

    async def compute_profile(self, user_id: str) -> Dict[str, Any]:
        since_date = datetime.utcnow() - timedelta(days=30)
        cursor = self.db["pomodoro_sessions"].find({
            "user_id": user_id,
            "synced_at": {"$gte": since_date.isoformat()}
        })
        sessions = await cursor.to_list(length=200)

        if not sessions:
            return {
                "focus_score": 75.0,
                "break_score": 80.0,
                "stress_level": 40.0,
                "efficiency": 78.0,
                "total_sessions": 0,
                "today_sessions_detail": [],
                "today_productivity_logs": []
            }

        total_work = sum(s.get("hardware_data", {}).get("work_min", 25) for s in sessions)
        total_pauses = sum(s.get("hardware_data", {}).get("pauses", 0) for s in sessions)
        completed = sum(1 for s in sessions if s.get("hardware_data", {}).get("completed", True))

        # Use AVERAGE pauses per session (not total accumulated) to keep scores proportional
        n = len(sessions)
        avg_pauses = total_pauses / n if n > 0 else 0
        completion_rate = (completed / n) * 100
        focus_score = max(0.0, min(100.0, completion_rate - (avg_pauses * 3.5)))
        stress_level = max(0.0, min(100.0, (avg_pauses * 8.0) + (100 - completion_rate) * 0.4))
        break_score = max(20.0, 100.0 - (stress_level * 0.5))
        efficiency = (focus_score * 0.6) + (completion_rate * 0.4)

        # 2. Extract Task-Type Specific Performance from productivity_logs
        cursor_tasks = self.db["productivity_logs"].find({
            "user_id": user_id,
            "timestamp": {"$gte": since_date.isoformat()}
        })
        task_logs = await cursor_tasks.to_list(length=200)

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
            focus = log.get("concentration_score", 50.0)
            p["focus_sum"] += focus
            
            hour = log.get("hour_of_day", 12)
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
            "today_sessions_detail": today_sessions_detail,
            "today_productivity_logs": today_productivity_logs
        }

    async def _get_today_sessions(self, user_id: str) -> List[Dict[str, Any]]:
        """Lấy danh sách chi tiết từng phiên Pomodoro hôm nay."""
        today_start = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
        cursor = self.db["pomodoro_sessions"].find(
            {
                "user_id": user_id,
                "synced_at": {"$gte": today_start.isoformat()}
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
        today_start = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
        cursor = self.db["productivity_logs"].find(
            {
                "user_id": user_id,
                "timestamp": {"$gte": today_start.isoformat()}
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

