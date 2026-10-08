"""
main.py - Entry Point cua Backend E-ink Clock
Kien truc: Clean Architecture + CQRS + Repository Pattern
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from motor.motor_asyncio import AsyncIOMotorClient

from core.database import connect_db, close_db

# Old routes
from routes.market_routes import router as market_router
from routes.schedule_routes import router as schedule_router
from routes.firmware_routes import router as firmware_router

# New API v1 routes
from api.v1.auth_router import router as auth_router
from api.v1.pomodoro_router import router as pomodoro_router
from api.v1.ai_router import router as ai_router
from api.v1.context_router import router as context_router
from api.v1.usage_router import router as usage_router
from api.v1.competition_router import router as competition_router

app = FastAPI(
    title="AI Productivity Watch - Backend API",
    description="Backend API for AI Productivity Watch",
    version="2.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.on_event("startup")
async def startup_db_client():
    await connect_db()
    # Backwards compatibility for old routers that might use app.mongodb_client
    app.mongodb_client = AsyncIOMotorClient("mongodb://localhost:27017")
    app.database = app.mongodb_client["Pomodoro_App"]

@app.on_event("shutdown")
async def shutdown_db_client():
    await close_db()
    if hasattr(app, "mongodb_client") and app.mongodb_client:
        app.mongodb_client.close()

# Legacy prefixes
app.include_router(market_router, prefix="/api/market", tags=["Market"])
app.include_router(schedule_router, prefix="/api/schedules", tags=["Schedules"])
app.include_router(firmware_router, prefix="/api/firmware", tags=["Firmware"])

# V1 prefixes
app.include_router(pomodoro_router, prefix="/api/v1/pomodoro", tags=["Pomodoro"])
app.include_router(auth_router, prefix="/api/v1/auth", tags=["Auth"])
app.include_router(ai_router, prefix="/api/v1/ai", tags=["AI Productivity"])
app.include_router(context_router, prefix="/api/v1/context", tags=["Context"])
app.include_router(usage_router, prefix="/api/v1/usage", tags=["Digital Wellbeing"])
app.include_router(competition_router, prefix="/api/v1/competition", tags=["Productivity Competition"])

@app.get("/")
async def root():
    return {
        "status": "OK",
        "message": "AI Productivity Watch Backend is running!",
        "version": "2.0.0"
    }
