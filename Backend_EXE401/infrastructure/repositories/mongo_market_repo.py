"""
infrastructure/repositories/mongo_market_repo.py - Tầng Infrastructure
Implement AbstractMarketRepository dùng MongoDB thật.
Đây là nơi DUY NHẤT chứa code giao tiếp MongoDB cho Market.
"""
from typing import List, Optional
from bson import ObjectId
from motor.motor_asyncio import AsyncIOMotorDatabase

from domain.entities.market_entity import MarketEntity
from domain.repositories.market_repository import AbstractMarketRepository

COLLECTION = "market_templates"


class MongoMarketRepository(AbstractMarketRepository):
    """Implement cụ thể dùng MongoDB."""

    def __init__(self, db: AsyncIOMotorDatabase):
        self._db = db

    def _to_entity(self, doc: dict) -> MarketEntity:
        """Chuyển đổi MongoDB document → MarketEntity."""
        return MarketEntity(
            id=str(doc["_id"]),
            author=doc.get("author", "Unknown"),
            thumbnail_url=doc.get("thumbnail_url", ""),
            design_json=doc.get("design_json", {}),
            likes=doc.get("likes", 0),
            timestamp=doc.get("timestamp"),
        )

    async def get_all(self) -> List[MarketEntity]:
        """Lấy toàn bộ templates từ MongoDB."""
        cursor = self._db[COLLECTION].find()
        return [self._to_entity(doc) async for doc in cursor]

    async def get_by_id(self, item_id: str) -> Optional[MarketEntity]:
        """Tìm template theo ObjectId."""
        try:
            doc = await self._db[COLLECTION].find_one({"_id": ObjectId(item_id)})
            return self._to_entity(doc) if doc else None
        except Exception:
            return None

    async def create(self, entity: MarketEntity) -> str:
        """Tạo template mới, trả về ID vừa tạo."""
        doc = {
            "author": entity.author,
            "thumbnail_url": entity.thumbnail_url,
            "design_json": entity.design_json,
            "likes": entity.likes,
            "timestamp": entity.timestamp,
        }
        result = await self._db[COLLECTION].insert_one(doc)
        return str(result.inserted_id)
