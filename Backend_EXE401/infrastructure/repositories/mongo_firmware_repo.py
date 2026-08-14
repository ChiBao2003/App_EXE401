"""
infrastructure/repositories/mongo_firmware_repo.py - Tầng Infrastructure
Implement AbstractFirmwareRepository dùng MongoDB.
"""
from typing import Optional, List
from bson import ObjectId
from motor.motor_asyncio import AsyncIOMotorDatabase

from domain.entities.firmware_entity import FirmwareEntity
from domain.repositories.firmware_repository import AbstractFirmwareRepository

COLLECTION = "firmwares"


class MongoFirmwareRepository(AbstractFirmwareRepository):

    def __init__(self, db: AsyncIOMotorDatabase):
        self._db = db

    def _to_entity(self, doc: dict) -> FirmwareEntity:
        return FirmwareEntity(
            id=str(doc["_id"]),
            version=doc.get("version", "0.0.0"),
            download_url=doc.get("download_url", ""),
            changelog=doc.get("changelog", ""),
            release_date=doc.get("release_date"),
        )

    async def get_latest(self) -> Optional[FirmwareEntity]:
        """Sắp xếp theo ngày release giảm dần, lấy bản mới nhất."""
        doc = await self._db[COLLECTION].find_one(sort=[("release_date", -1)])
        return self._to_entity(doc) if doc else None

    async def get_all(self) -> List[FirmwareEntity]:
        cursor = self._db[COLLECTION].find()
        result = []
        async for doc in cursor:
            result.append(self._to_entity(doc))
        return result
