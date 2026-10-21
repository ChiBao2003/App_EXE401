"""
core/database.py - Tầng Core
Quản lý kết nối MongoDB tập trung, dùng Dependency Injection.
"""
import os
from motor.motor_asyncio import AsyncIOMotorClient, AsyncIOMotorDatabase

MONGO_URI = os.getenv("MONGO_URI", "mongodb://localhost:27017")
DATABASE_NAME = os.getenv("MONGO_DB_NAME", "Pomodoro_App")

_client: AsyncIOMotorClient = None


async def init_db_indexes() -> None:
    """Tạo các index cần thiết (Sparse Unique Index) để chống ghi trùng idempotency."""
    if not _client:
        return
    db = _client[DATABASE_NAME]
    try:
        await db["pomodoro_sessions"].create_index(
            [("session_id", 1)],
            unique=True,
            sparse=True,
            name="uniq_pomodoro_session_id"
        )
        await db["productivity_logs"].create_index(
            [("session_id", 1)],
            unique=True,
            sparse=True,
            name="uniq_productivity_session_id"
        )
        print("[OK] Khoi tao MongoDB unique indexes thanh cong.")
    except Exception as e:
        print(f"[WARN] Khoi tao indexes (khong anh huong he thong): {e}")


async def connect_db() -> None:
    """Khởi tạo kết nối MongoDB khi server start."""
    global _client
    _client = AsyncIOMotorClient(MONGO_URI)
    print(f"[OK] Ket noi MongoDB thanh cong ({DATABASE_NAME})")
    await init_db_indexes() 


async def close_db() -> None:
    """Đóng kết nối MongoDB khi server shutdown."""
    global _client
    if _client:
        _client.close()
        print("[CLOSE] Da dong ket noi MongoDB.")


def get_database() -> AsyncIOMotorDatabase:
    """
    FastAPI Dependency Injection function.
    Sử dụng: db: AsyncIOMotorDatabase = Depends(get_database)
    """
    return _client[DATABASE_NAME]
