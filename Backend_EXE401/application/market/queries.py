"""
application/market/queries.py - Tầng Application (CQRS - Query)
Chứa các Use Cases chỉ ĐỌC dữ liệu Market.
Không biết gì về HTTP, FastAPI hay MongoDB cụ thể.
"""
from typing import List
from domain.entities.market_entity import MarketEntity
from domain.repositories.market_repository import AbstractMarketRepository


class GetAllMarketTemplatesQuery:
    """
    Use Case: Lấy toàn bộ danh sách mẫu thiết kế từ Chợ.
    Đây là Query (chỉ đọc) theo mô hình CQRS.
    """

    def __init__(self, repository: AbstractMarketRepository):
        self._repo = repository

    async def execute(self) -> List[dict]:
        """
        Thực thi query, trả về list dict có thể serialized thành JSON.
        """
        entities: List[MarketEntity] = await self._repo.get_all()
        return [
            {
                "_id": e.id,
                "author": e.author,
                "thumbnail_url": e.thumbnail_url,
                "design_json": e.design_json,
                "likes": e.likes,
                "timestamp": e.timestamp.isoformat() if hasattr(e.timestamp, 'isoformat') else e.timestamp,
            }
            for e in entities
        ]
