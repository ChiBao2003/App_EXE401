"""
infrastructure/repositories/mongo_schedule_repo.py - Tầng Infrastructure
Implement AbstractScheduleRepository dùng MongoDB.
"""
from typing import List
from bson import ObjectId
from motor.motor_asyncio import AsyncIOMotorDatabase

from domain.entities.schedule_entity import ScheduleEntity
from domain.repositories.schedule_repository import AbstractScheduleRepository

COLLECTION = "schedules"


class MongoScheduleRepository(AbstractScheduleRepository):

    def __init__(self, db: AsyncIOMotorDatabase):
        self._db = db

    def _to_entity(self, doc: dict) -> ScheduleEntity:
        return ScheduleEntity(
            id=str(doc["_id"]),
            day_of_week=doc.get("day_of_week", "Mon"),
            hour=doc.get("hour", 8),
            minute=doc.get("minute", 0),
            label=doc.get("label", ""),
            is_active=doc.get("is_active", True),
        )

    async def get_all(self) -> List[ScheduleEntity]:
        cursor = self._db[COLLECTION].find()
        result = []
        async for doc in cursor:
            result.append(self._to_entity(doc))
        return result

    async def create(self, entity: ScheduleEntity) -> str:
        doc = {
            "day_of_week": entity.day_of_week,
            "hour": entity.hour,
            "minute": entity.minute,
            "label": entity.label,
            "is_active": entity.is_active,
        }
        result = await self._db[COLLECTION].insert_one(doc)
        return str(result.inserted_id)

    async def delete(self, item_id: str) -> bool:
        result = await self._db[COLLECTION].delete_one({"_id": ObjectId(item_id)})
        return result.deleted_count > 0
