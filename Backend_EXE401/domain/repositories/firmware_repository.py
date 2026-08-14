"""
domain/repositories/firmware_repository.py - Tầng Domain
Abstract interface cho Firmware Repository.
"""
from abc import ABC, abstractmethod
from typing import Optional
from domain.entities.firmware_entity import FirmwareEntity


class AbstractFirmwareRepository(ABC):

    @abstractmethod
    async def get_latest(self) -> Optional[FirmwareEntity]:
        """Lấy bản firmware mới nhất."""
        ...

    @abstractmethod
    async def get_all(self):
        """Lấy toàn bộ danh sách firmware."""
        ...
