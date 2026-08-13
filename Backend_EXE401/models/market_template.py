from pydantic import BaseModel
from typing import Dict, Any, Optional
from datetime import datetime

class MarketTemplate(BaseModel):
    author: str
    thumbnail_url: str
    design_json: Dict[str, Any]
    timestamp: Optional[datetime] = None
    likes: int = 0
