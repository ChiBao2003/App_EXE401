"""
main.py - Entry Point của Backend E-ink Clock
Kiến trúc: Clean Architecture + CQRS + Repository Pattern
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from core.database import connect_db, close_db
from api.v1.market_router import router as market_router
from api.v1.schedule_router import router as schedule_router
from api.v1.firmware_router import router as firmware_router

# ============================================================
# Khởi tạo FastAPI App
# ============================================================
app = FastAPI(
    title="E-ink Clock Backend API",
    description="""
## Kiến trúc: Clean Architecture + CQRS + Repository Pattern

**Tầng Domain** → **Tầng Infrastructure** → **Tầng Application (CQRS)** → **Tầng API Controller**

### Các nhóm API:
- **Market** `/api/v1/market` - Quản lý Chợ hiệu ứng E-ink
- **Schedules** `/api/v1/schedules` - Quản lý lịch nhắc nhở tuần
- **Firmware** `/api/v1/firmware` - Cập nhật OTA cho ESP32
    """,
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

# ============================================================
# CORS Middleware - Cho phép Flutter/Web gọi API
# ============================================================
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ============================================================
# Đăng ký Routes API v1
# ============================================================
app.include_router(market_router, prefix="/api/v1/market", tags=["🛒 Market"])
app.include_router(schedule_router, prefix="/api/v1/schedules", tags=["📅 Schedules"])
app.include_router(firmware_router, prefix="/api/v1/firmware", tags=["⚙️ Firmware"])

# ============================================================
# Lifecycle Events - Kết nối / Đóng Database
# ============================================================
@app.on_event("startup")
async def startup():
    await connect_db()


@app.on_event("shutdown")
async def shutdown():
    await close_db()


# ============================================================
# Health Check Endpoint
# ============================================================
@app.get("/", tags=["Health"])
async def root():
    return {
        "status": "✅ OK",
        "message": "E-ink Clock Backend API đang chạy!",
        "docs": "/docs",
        "version": "1.0.0",
        "architecture": "Clean Architecture + CQRS + Repository",
    }
