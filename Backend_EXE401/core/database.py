"""
core/database.py - Tầng Core
Quản lý kết nối MongoDB tập trung, dùng Dependency Injection.
"""
from motor.motor_asyncio import AsyncIOMotorClient, AsyncIOMotorDatabase

MONGO_URI = "mongodb://localhost:27017"
DATABASE_NAME = "Pomodoro_App"

_client: AsyncIOMotorClient = None


async def connect_db() -> None:
    """Khởi tạo kết nối MongoDB khi server start."""
    global _client
    _client = AsyncIOMotorClient(MONGO_URI)
    print(f"[OK] Ket noi MongoDB thanh cong ({DATABASE_NAME})") 


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
