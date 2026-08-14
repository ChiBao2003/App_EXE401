"""
api/v1/market_router.py - Tầng API Controller (Mỏng nhất có thể)
Chỉ nhận HTTP Request → Gọi Application Layer → Trả HTTP Response.
KHÔNG chứa bất kỳ business logic hay truy vấn database nào.
"""
from fastapi import APIRouter, Depends, HTTPException
from motor.motor_asyncio import AsyncIOMotorDatabase

from core.database import get_database
from infrastructure.repositories.mongo_market_repo import MongoMarketRepository
from application.market.queries import GetAllMarketTemplatesQuery
from application.market.commands import UploadMarketTemplateCommand
from models.market_template import MarketTemplate

router = APIRouter()


def _get_repo(db: AsyncIOMotorDatabase = Depends(get_database)) -> MongoMarketRepository:
    """Dependency Injection: Tạo repository với database đã được inject."""
    return MongoMarketRepository(db)


@router.get("/", summary="Lấy danh sách mẫu thiết kế trên Chợ")
async def get_market_templates(repo: MongoMarketRepository = Depends(_get_repo)):
    """
    [QUERY] Trả về toàn bộ mẫu thiết kế từ Chợ hiệu ứng.
    """
    query = GetAllMarketTemplatesQuery(repository=repo)
    return await query.execute()


@router.post("/", summary="Tải lên mẫu thiết kế mới")
async def upload_market_template(
    template: MarketTemplate,
    repo: MongoMarketRepository = Depends(_get_repo),
):
    """
    [COMMAND] Upload một bản thiết kế mới lên Chợ.
    """
    command = UploadMarketTemplateCommand(repository=repo)
    return await command.execute(
        author=template.author,
        thumbnail_url=template.thumbnail_url,
        design_json=template.design_json,
        likes=template.likes,
    )
