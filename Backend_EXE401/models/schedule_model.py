from pydantic import BaseModel
from typing import List, Optional

class ScheduleModel(BaseModel):
    user_id: str
    title: str
    time: str
    days_of_week: List[int]
    is_active: bool = True
