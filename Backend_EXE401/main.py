from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routes.market_routes import router as market_router
from routes.schedule_routes import router as schedule_router
from routes.firmware_routes import router as firmware_router
from motor.motor_asyncio import AsyncIOMotorClient
import os

app = FastAPI(title="E-ink Clock Backend", description="Backend API cho ứng dụng Đồng hồ E-ink", version="1.0.0")

# Cấu hình CORS cho phép App Flutter gọi API
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Đăng ký các Routes
app.include_router(market_router, prefix="/api/market", tags=["Market"])
app.include_router(schedule_router, prefix="/api/schedules", tags=["Schedules"])
app.include_router(firmware_router, prefix="/api/firmware", tags=["Firmware"])

# Biến toàn cục chứa kết nối Database
app.mongodb_client = None
app.database = None

@app.on_event("startup")
async def startup_db_client():
    # Kết nối trực tiếp vào máy chủ MongoDB nội bộ
    app.mongodb_client = AsyncIOMotorClient("mongodb://localhost:27017")
    # Lấy đúng tên Database mà bạn vừa tạo
    app.database = app.mongodb_client["Pomodoro_App"]
    print("Da ket noi thanh cong toi Database MongoDB (Pomodoro_App)!")

@app.on_event("shutdown")
async def shutdown_db_client():
    app.mongodb_client.close()
    print("Đã đóng kết nối Database.")

# Đăng ký các Routes
app.include_router(market_router, prefix="/api/market", tags=["Market"])

@app.get("/")
async def root():
    return {"message": "Welcome to E-ink Clock Backend API! Mở /docs để xem tài liệu Swagger UI."}
