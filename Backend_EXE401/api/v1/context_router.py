"""
api/v1/context_router.py - Context-Aware Productivity endpoints
Tong hop: Thoi tiet + Loi khuyen theo ngu canh
"""
from fastapi import APIRouter, Query, Depends
from application.context.weather_service import get_weather, get_productivity_advice_from_weather
from core.security import get_current_user_id

router = APIRouter()


@router.get("/today", summary="Lay tong hop ngu canh hom nay (thoi tiet + loi khuyen)")
async def get_today_context(
    lat: float = Query(default=10.762622, description="Vi do (mac dinh: TP.HCM)"),
    lon: float = Query(default=106.660172, description="Kinh do (mac dinh: TP.HCM)"),
    user_id: str = Depends(get_current_user_id),
):
    """
    Tra ve thong tin ngu canh tong hop cho hom nay:
    - Thoi tiet hien tai
    - Loi khuyen nang suat dua tren thoi tiet
    """
    weather = await get_weather(lat=lat, lon=lon)
    advice = get_productivity_advice_from_weather(weather)

    return {
        "weather": weather,
        "productivity_advice": advice,
        "context_summary": (
            f"{weather['description'].capitalize()}, "
            f"{weather['temp_c']}°C, do am {weather['humidity']}%"
        ),
    }


@router.get("/weather", summary="Chi lay thong tin thoi tiet")
async def get_current_weather(
    lat: float = Query(default=10.762622),
    lon: float = Query(default=106.660172),
):
    """Lay thoi tiet hien tai (khong can token)."""
    return await get_weather(lat=lat, lon=lon)
