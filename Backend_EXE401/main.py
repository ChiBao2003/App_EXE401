<<<<<<< Updated upstream
<<<<<<< HEAD
=======
=======
<<<<<<< Updated upstream
>>>>>>> Stashed changes
"""
main.py - Entry Point cua Backend E-ink Clock
Kien truc: Clean Architecture + CQRS + Repository Pattern
"""
>>>>>>> 8020cfb (feat: AI Coach fallback chain + rule-based V2 + usage tracking)
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routes.market_routes import router as market_router
from routes.schedule_routes import router as schedule_router
from routes.firmware_routes import router as firmware_router
from motor.motor_asyncio import AsyncIOMotorClient
import os

<<<<<<< HEAD
app = FastAPI(title="E-ink Clock Backend", description="Backend API cho ứng dụng Đồng hồ E-ink", version="1.0.0")

# Cấu hình CORS cho phép App Flutter gọi API
=======
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
<<<<<<< Updated upstream
>>>>>>> 8020cfb (feat: AI Coach fallback chain + rule-based V2 + usage tracking)
=======
=======

# ==========================================
# THI_DUA_FEATURE_START (By Gemini)
# ==========================================
from api.v1.competition_router import router as competition_router
# ==========================================
# THI_DUA_FEATURE_END
# ==========================================

app = FastAPI(
    title="AI Productivity Watch - Backend API",
    description="Backend API with Clean Architecture",
    version="2.0.0",
)

>>>>>>> Stashed changes
>>>>>>> Stashed changes
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

<<<<<<< Updated upstream
<<<<<<< HEAD
# Đăng ký các Routes
app.include_router(market_router, prefix="/api/market", tags=["Market"])
app.include_router(schedule_router, prefix="/api/schedules", tags=["Schedules"])
app.include_router(firmware_router, prefix="/api/firmware", tags=["Firmware"])

# Biến toàn cục chứa kết nối Database
app.mongodb_client = None
app.database = None
=======
=======
<<<<<<< Updated upstream
>>>>>>> Stashed changes
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
>>>>>>> 8020cfb (feat: AI Coach fallback chain + rule-based V2 + usage tracking)

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

<<<<<<< Updated upstream
# Đăng ký các Routes
app.include_router(market_router, prefix="/api/market", tags=["Market"])
=======
=======
@app.on_event("startup")
async def startup_db_client():
    app.mongodb_client = AsyncIOMotorClient("mongodb://localhost:27017")
    app.database = app.mongodb_client["Pomodoro_App"]
    print("Da ket noi thanh cong toi Database MongoDB (Pomodoro_App)!")

@app.on_event("shutdown")
async def shutdown_db_client():
    if hasattr(app, "mongodb_client") and app.mongodb_client:
        app.mongodb_client.close()
        print("Đã đóng kết nối Database.")

app.include_router(market_router, prefix="/api/market", tags=["Market"])
app.include_router(schedule_router, prefix="/api/schedules", tags=["Schedules"])
app.include_router(firmware_router, prefix="/api/firmware", tags=["Firmware"])
app.include_router(pomodoro_router, prefix="/api/v1/pomodoro", tags=["Pomodoro"])
app.include_router(auth_router, prefix="/api/v1/auth", tags=["Auth"])
app.include_router(ai_router, prefix="/api/v1/ai", tags=["AI Productivity"])
app.include_router(context_router, prefix="/api/v1/context", tags=["Context"])
app.include_router(usage_router, prefix="/api/v1/usage", tags=["Digital Wellbeing"])

# ==========================================
# THI_DUA_FEATURE_START (By Gemini)
# ==========================================
app.include_router(competition_router, prefix="/api/v1/competition", tags=["Productivity Competition"])
# ==========================================
# THI_DUA_FEATURE_END
# ==========================================
>>>>>>> Stashed changes
>>>>>>> Stashed changes

@app.get("/")
async def root():
<<<<<<< HEAD
    return {"message": "Welcome to E-ink Clock Backend API! Mở /docs để xem tài liệu Swagger UI."}
=======
    return {
<<<<<<< Updated upstream
        "status": "OK",
        "message": "AI Productivity Watch Backend dang chay!",
        "docs": "/docs",
        "version": "2.0.0",
        "features": ["Auth JWT", "Adaptive Pomodoro AI", "Burnout Detection", "Context Awareness", "Digital Wellbeing"],
=======
<<<<<<< Updated upstream
        "status": "✅ OK",
        "message": "E-ink Clock Backend API đang chạy!",
        "docs": "/docs",
        "version": "1.0.0",
        "architecture": "Clean Architecture + CQRS + Repository",
=======
        "status": "OK",
        "message": "AI Productivity Watch Backend dang chay!",
        "version": "2.0.0",
>>>>>>> Stashed changes
>>>>>>> Stashed changes
    }
>>>>>>> 8020cfb (feat: AI Coach fallback chain + rule-based V2 + usage tracking)
