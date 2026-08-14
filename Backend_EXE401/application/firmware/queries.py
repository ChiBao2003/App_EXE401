"""
application/firmware/queries.py - Tầng Application (CQRS - Query)
"""
from typing import Optional, List
from domain.repositories.firmware_repository import AbstractFirmwareRepository


class GetLatestFirmwareQuery:
    def __init__(self, repository: AbstractFirmwareRepository):
        self._repo = repository

    async def execute(self) -> Optional[dict]:
        entity = await self._repo.get_latest()
        if not entity:
            return None
        return {
            "_id": entity.id,
            "version": entity.version,
            "download_url": entity.download_url,
            "changelog": entity.changelog,
            "release_date": entity.release_date.isoformat() if hasattr(entity.release_date, 'isoformat') else entity.release_date,
        }


class GetAllFirmwaresQuery:
    def __init__(self, repository: AbstractFirmwareRepository):
        self._repo = repository

    async def execute(self) -> List[dict]:
        entities = await self._repo.get_all()
        return [
            {
                "_id": e.id,
                "version": e.version,
                "download_url": e.download_url,
                "changelog": e.changelog,
                "release_date": e.release_date.isoformat() if hasattr(e.release_date, 'isoformat') else e.release_date,
            }
            for e in entities
        ]
