"""
domain/entities/schedule_entity.py - Tầng Domain
Pure Python entity cho Lịch nhắc nhở.
"""
from dataclasses import dataclass, field
from typing import Optional


@dataclass
class ScheduleEntity:
    """Entity đại diện cho một lịch nhắc nhở trong tuần."""
    day_of_week: str       # "Mon", "Tue", "Wed"...
    hour: int              # 0-23
    minute: int            # 0-59
    label: str             # Nhãn mô tả lịch
    is_active: bool = True
    id: Optional[str] = None
