"""
application/market/commands.py - Tầng Application (CQRS - Command)
Chứa các Use Cases GHI dữ liệu Market.
"""
from datetime import datetime, timezone
from domain.entities.market_entity import MarketEntity
from domain.repositories.market_repository import AbstractMarketRepository


class UploadMarketTemplateCommand:
    """
    Use Case: Upload một mẫu thiết kế mới lên Chợ.
    Đây là Command (ghi dữ liệu) theo mô hình CQRS.
    """

    def __init__(self, repository: AbstractMarketRepository):
        self._repo = repository

    async def execute(self, author: str, thumbnail_url: str, design_json: dict, likes: int = 0) -> dict:
        """
        Business logic: Tạo entity → Gọi repository.create() → Trả về kết quả.
        """
        # Tự động gán timestamp hiện tại nếu không có
        entity = MarketEntity(
            author=author,
            thumbnail_url=thumbnail_url,
            design_json=design_json,
            likes=likes,
            timestamp=datetime.now(timezone.utc),
        )

        inserted_id = await self._repo.create(entity)

        return {
            "message": "Upload template thành công!",
            "inserted_id": inserted_id,
        }
