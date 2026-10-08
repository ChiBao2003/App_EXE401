"""
application/schedule/commands.py - Tầng Application (CQRS - Command)
"""
from domain.entities.schedule_entity import ScheduleEntity
from domain.repositories.schedule_repository import AbstractScheduleRepository


class CreateScheduleCommand:
    def __init__(self, repository: AbstractScheduleRepository):
        self._repo = repository

    async def execute(self, day_of_week: str, hour: int, minute: int, label: str) -> dict:
        entity = ScheduleEntity(
            day_of_week=day_of_week,
            hour=hour,
            minute=minute,
            label=label,
        )
        inserted_id = await self._repo.create(entity)
        return {"message": "Tạo lịch thành công!", "inserted_id": inserted_id}


class DeleteScheduleCommand:
    def __init__(self, repository: AbstractScheduleRepository):
        self._repo = repository

    async def execute(self, item_id: str) -> dict:
        success = await self._repo.delete(item_id)
        return {"message": "Xóa thành công!" if success else "Không tìm thấy lịch.", "success": success}
