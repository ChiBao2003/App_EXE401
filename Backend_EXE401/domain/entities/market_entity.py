"""
domain/entities/market_entity.py - Tầng Domain
Pure Python entity - không phụ thuộc vào FastAPI hay MongoDB.
"""
from dataclasses import dataclass, field
from typing import Dict, Any, Optional
from datetime import datetime


@dataclass
class MarketEntity:
    """Entity đại diện cho một mẫu thiết kế E-ink trong Chợ hiệu ứng."""
    author: str
    thumbnail_url: str
    design_json: Dict[str, Any]
    likes: int = 0
    timestamp: Optional[datetime] = None
    id: Optional[str] = None
