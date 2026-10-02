"""
application/ai/burnout_detector.py
Calculates Burnout Risk Score (0-100) using rolling 14-day metrics.
"""
from typing import Dict, Any
from datetime import datetime, timedelta
from motor.motor_asyncio import AsyncIOMotorDatabase

class BurnoutDetector:
    def __init__(self, db: AsyncIOMotorDatabase):
        self.db = db

    async def calculate_burnout_risk(self, user_id: str, unlock_count: int = 12) -> Dict[str, Any]:
        since_date = datetime.utcnow() - timedelta(days=14)
        cursor = self.db["pomodoro_sessions"].find({
            "user_id": user_id,
            "synced_at": {"$gte": since_date.isoformat()}
        })
        sessions = await cursor.to_list(length=100)

        total_work_mins = sum(s.get("hardware_data", {}).get("work_min", 25) for s in sessions)
        skipped_breaks = sum(1 for s in sessions if not s.get("hardware_data", {}).get("take_break", True))
        total_pauses = sum(s.get("hardware_data", {}).get("pauses", 0) for s in sessions)

        overtime_penalty = max(0, (total_work_mins - (14 * 8 * 60)) / 60) * 4.0
        break_penalty = skipped_breaks * 5.0
        distraction_penalty = (total_pauses + unlock_count) * 1.5

        risk_score = min(100.0, max(0.0, 20.0 + overtime_penalty + break_penalty + distraction_penalty))

        risk_level = "LOW"
        if risk_score >= 70:
            risk_level = "CRITICAL"
        elif risk_score >= 45:
            risk_level = "MODERATE"

        return {
            "burnout_risk_score": round(risk_score, 1),
            "risk_level": risk_level,
            "factors": {
                "overtime_hours": round(max(0, (total_work_mins - (14 * 8 * 60)) / 60), 1),
                "skipped_breaks": skipped_breaks,
                "distractions": total_pauses + unlock_count
            }
        }
