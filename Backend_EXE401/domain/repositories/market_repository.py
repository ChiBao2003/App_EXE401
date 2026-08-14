"""
domain/repositories/market_repository.py - Tầng Domain
Abstract interface cho Market Repository.
Infrastructure layer sẽ implement class này.
"""
from abc import ABC, abstractmethod
from typing import List, Optional
from domain.entities.market_entity import MarketEntity


class AbstractMarketRepository(ABC):
    """
    Interface (Abstract class) định nghĩa các phép tính trên Market.
    Tầng Application sẽ chỉ giao tiếp qua interface này,
    không biết gì về MongoDB hay database cụ thể.
    """

    @abstractmethod
    async def get_all(self) -> List[MarketEntity]:
        """Lấy toàn bộ mẫu thiết kế từ Chợ."""
        ...

    @abstractmethod
    async def get_by_id(self, item_id: str) -> Optional[MarketEntity]:
        """Tìm một mẫu thiết kế theo ID."""
        ...

    @abstractmethod
    async def create(self, entity: MarketEntity) -> str:
        """Tạo mới một mẫu thiết kế, trả về ID được tạo ra."""
        ...
