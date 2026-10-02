"""
main.py - Entry Point cua Backend E-ink Clock
Kien truc: Clean Architecture + CQRS + Repository Pattern
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from core.database import connect_db, close_db
from api.v1.market_router import router as market_router
from api.v1.schedule_router import router as schedule_router
from api.v1.firmware_router import router as firmware_router
from api.v1.pomodoro_router import router as pomodoro_router
# Phase 1 AI Productivity - cac router moi
from api.v1.auth_router import router as auth_router
from api.v1.ai_router import router as ai_router
from api.v1.context_router import router as context_router
from api.v1.usage_router import router as usage_router

# ============================================================
# Khởi tạo FastAPI App
# ============================================================
app = FastAPI(
    title="AI Productivity Watch - Backend API",
    description="""
## Kien truc: Clean Architecture + CQRS + Repository Pattern

### Nhom API:
- **Auth** `/api/v1/auth` - Dang ky / Dang nhap / JWT
- **AI** `/api/v1/ai` - Adaptive Pomodoro, Burnout Risk, Coach
- **Context** `/api/v1/context` - Thoi tiet, ngu canh nang suat
- **Pomodoro** `/api/v1/pomodoro` - Dong bo phien Pomodoro tu ESP32
- **Market** `/api/v1/market` - Cho hieu ung E-ink
- **Schedules** `/api/v1/schedules` - Lich nhac nho
- **Firmware** `/api/v1/firmware` - Cap nhat OTA cho ESP32
    """,
    version="2.0.0",
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
# === Existing routes ===
app.include_router(market_router, prefix="/api/v1/market", tags=["Market"])
app.include_router(schedule_router, prefix="/api/v1/schedules", tags=["Schedules"])
app.include_router(firmware_router, prefix="/api/v1/firmware", tags=["Firmware"])
app.include_router(pomodoro_router, prefix="/api/v1/pomodoro", tags=["Pomodoro"])
# === Phase 1 AI Productivity routes ===
app.include_router(auth_router, prefix="/api/v1/auth", tags=["Auth"])
app.include_router(ai_router, prefix="/api/v1/ai", tags=["AI Productivity"])
app.include_router(context_router, prefix="/api/v1/context", tags=["Context"])
# === Phase 2 Digital Wellbeing routes ===
app.include_router(usage_router, prefix="/api/v1", tags=["Digital Wellbeing"])

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
        "status": "OK",
        "message": "AI Productivity Watch Backend dang chay!",
        "docs": "/docs",
        "version": "2.0.0",
        "features": ["Auth JWT", "Adaptive Pomodoro AI", "Burnout Detection", "Context Awareness", "Digital Wellbeing"],
    }
