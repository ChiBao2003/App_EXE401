"""
domain/entities/user_entity.py - Pydantic models cho Auth
"""
from pydantic import BaseModel, EmailStr, Field
from typing import Optional, List
from datetime import datetime


class UserCreate(BaseModel):
    """Payload dang ky tai khoan moi."""
    email: str = Field(..., description="Email nguoi dung")
    password: str = Field(..., min_length=6, description="Mat khau toi thieu 6 ky tu")
    display_name: str = Field(..., min_length=2, description="Ten hien thi")
    timezone: str = Field(default="Asia/Ho_Chi_Minh")


class UserLogin(BaseModel):
    """Payload dang nhap."""
    email: str
    password: str


class UserOut(BaseModel):
    """Thong tin user tra ve cho client (khong co password)."""
    id: str
    email: str
    display_name: str
    timezone: str
    created_at: str
    preferences: dict = {}
    digital_twin: dict = {}


class TokenOut(BaseModel):
    """JWT token response."""
    access_token: str
    token_type: str = "bearer"
    user: UserOut


class DigitalTwinProfile(BaseModel):
    """Digital Twin profile cua nguoi dung (cap nhat theo thoi gian)."""
    productivity_profile: str = "unknown"
    focus_score_avg: float = 0.0
    optimal_work_duration: int = 25
    optimal_break_duration: int = 5
    peak_hours: List[int] = []
    burnout_risk_score: float = 0.0
    last_updated: Optional[str] = None
