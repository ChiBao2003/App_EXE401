"""
domain/entities/productivity_entity.py - Models cho Productivity Logging & AI
"""
from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime


class ProductivityLog(BaseModel):
    """Log mot phien lam viec. Luu vao MongoDB + TimescaleDB (Phase 2)."""
    user_id: str
    session_id: Optional[str] = None
    work_min: int = 25
    break_min: int = 5
    actual_work_s: int = 0           # Thoi gian thuc te lam viec (giay)
    concentration_score: float = 50.0  # 0-100, do tap trung tu nguoi dung danh gia
    interruptions: int = 0
    task_type: str = "general"        # coding / reading / meeting / general
    completed: bool = False
    break_skipped: bool = False
    source: str = "app"               # app / watch
    timestamp: Optional[str] = None   # ISO format

    def model_post_init(self, __context):
        if not self.timestamp:
            self.timestamp = datetime.utcnow().isoformat()


class AIRecommendation(BaseModel):
    """Ket qua goi y tu Adaptive Pomodoro Agent."""
    work_min: int
    break_min: int
    reason: str
    confidence: float = 0.8           # 0.0 - 1.0
    source: str = "q_learning"        # q_learning / rule_based / llm


class SessionFeedback(BaseModel):
    """Payload sau khi phien ket thuc - dung de cap nhat Q-table."""
    user_id: str
    session_id: str
    recommendation_id: Optional[str] = None
    work_min: int
    break_min: int
    concentration_score: float = Field(..., ge=0, le=100)
    completion_rate: float = Field(..., ge=0, le=100)  # % hoan thanh
    interruptions: int = 0
    break_skipped: bool = False
    task_type: str = "general"
    hour_of_day: int = Field(..., ge=0, le=23)
    day_of_week: int = Field(..., ge=0, le=6)


class BurnoutRiskResponse(BaseModel):
    """Ket qua danh gia nguy co burnout."""
    risk_score: float              # 0-100
    risk_level: str                # low / medium / high / critical
    indicators: List[str]          # Danh sach dau hieu phat hien
    advice: str                    # Loi khuyen
