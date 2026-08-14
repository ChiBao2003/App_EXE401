"""
domain/repositories/schedule_repository.py - Tầng Domain
Abstract interface cho Schedule Repository.
"""
from abc import ABC, abstractmethod
from typing import List, Optional
from domain.entities.schedule_entity import ScheduleEntity


class AbstractScheduleRepository(ABC):

    @abstractmethod
    async def get_all(self) -> List[ScheduleEntity]:
        """Lấy toàn bộ lịch nhắc nhở."""
        ...

    @abstractmethod
    async def create(self, entity: ScheduleEntity) -> str:
        """Tạo mới lịch nhắc nhở, trả về ID."""
        ...

    @abstractmethod
    async def delete(self, item_id: str) -> bool:
        """Xóa lịch nhắc nhở theo ID."""
        ...
