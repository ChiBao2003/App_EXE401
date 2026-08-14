"""
api/v1/schedule_router.py - Tầng API Controller (Mỏng)
"""
from fastapi import APIRouter, Depends
from motor.motor_asyncio import AsyncIOMotorDatabase

from core.database import get_database
from infrastructure.repositories.mongo_schedule_repo import MongoScheduleRepository
from application.schedule.queries import GetAllSchedulesQuery
from application.schedule.commands import CreateScheduleCommand, DeleteScheduleCommand

router = APIRouter()


def _get_repo(db: AsyncIOMotorDatabase = Depends(get_database)) -> MongoScheduleRepository:
    return MongoScheduleRepository(db)


@router.get("/", summary="Lấy toàn bộ lịch nhắc nhở")
async def get_schedules(repo: MongoScheduleRepository = Depends(_get_repo)):
    query = GetAllSchedulesQuery(repository=repo)
    return await query.execute()


@router.post("/", summary="Tạo lịch nhắc nhở mới")
async def create_schedule(schedule: dict, repo: MongoScheduleRepository = Depends(_get_repo)):
    command = CreateScheduleCommand(repository=repo)
    return await command.execute(
        day_of_week=schedule.get("day_of_week", "Mon"),
        hour=schedule.get("hour", 8),
        minute=schedule.get("minute", 0),
        label=schedule.get("label", ""),
    )


@router.delete("/{item_id}", summary="Xóa lịch nhắc nhở theo ID")
async def delete_schedule(item_id: str, repo: MongoScheduleRepository = Depends(_get_repo)):
    command = DeleteScheduleCommand(repository=repo)
    return await command.execute(item_id)
