"""
api/v1/firmware_router.py - Tầng API Controller (Mỏng)
"""
from fastapi import APIRouter, Depends, HTTPException
from motor.motor_asyncio import AsyncIOMotorDatabase

from core.database import get_database
from infrastructure.repositories.mongo_firmware_repo import MongoFirmwareRepository
from application.firmware.queries import GetLatestFirmwareQuery, GetAllFirmwaresQuery

router = APIRouter()


def _get_repo(db: AsyncIOMotorDatabase = Depends(get_database)) -> MongoFirmwareRepository:
    return MongoFirmwareRepository(db)


@router.get("/", summary="Lấy toàn bộ danh sách firmware")
async def get_all_firmwares(repo: MongoFirmwareRepository = Depends(_get_repo)):
    query = GetAllFirmwaresQuery(repository=repo)
    return await query.execute()


@router.get("/latest", summary="Lấy bản firmware mới nhất (OTA)")
async def get_latest_firmware(repo: MongoFirmwareRepository = Depends(_get_repo)):
    query = GetLatestFirmwareQuery(repository=repo)
    result = await query.execute()
    if not result:
        raise HTTPException(status_code=404, detail="Không tìm thấy firmware nào.")
    return result
