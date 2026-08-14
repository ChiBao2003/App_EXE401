"""
application/schedule/queries.py - Tầng Application (CQRS - Query)
"""
from typing import List
from domain.repositories.schedule_repository import AbstractScheduleRepository


class GetAllSchedulesQuery:
    def __init__(self, repository: AbstractScheduleRepository):
        self._repo = repository

    async def execute(self) -> List[dict]:
        entities = await self._repo.get_all()
        return [
            {
                "_id": e.id,
                "day_of_week": e.day_of_week,
                "hour": e.hour,
                "minute": e.minute,
                "label": e.label,
                "is_active": e.is_active,
            }
            for e in entities
        ]
