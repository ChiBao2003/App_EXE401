<<<<<<< Updated upstream
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
=======
from motor.motor_asyncio import AsyncIOMotorClient

mongodb_client = None
database = None

async def connect_db():
    global mongodb_client, database
    mongodb_client = AsyncIOMotorClient("mongodb://localhost:27017")
    database = mongodb_client["Pomodoro_App"]
    print("Connected to MongoDB!")

async def close_db():
    global mongodb_client
    if mongodb_client:
        mongodb_client.close()
        print("Closed MongoDB connection.")

def get_database():
    return database
>>>>>>> Stashed changes
