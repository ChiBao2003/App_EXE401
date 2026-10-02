"""
application/context/weather_service.py - Lay thong tin thoi tiet tu OpenWeatherMap
Cache ket qua 30 phut de giam goi API.
"""
import httpx
import time
from typing import Optional, Dict

from core.config import OPENWEATHER_API_KEY

# In-memory cache: {cache_key: (data, expire_timestamp)}
_cache: dict = {}
CACHE_TTL = 1800  # 30 phut


async def get_weather(lat: float = 10.762622, lon: float = 106.660172) -> dict:
    """
    Lay thoi tiet hien tai tu OpenWeatherMap Free API.
    Tra ve dict voi: temp_c, condition, humidity, description, icon
    """
    cache_key = f"{lat:.2f}_{lon:.2f}"
    now = time.time()

    # Kiem tra cache
    if cache_key in _cache:
        data, expire = _cache[cache_key]
        if now < expire:
            return data

    # Goi API
    if not OPENWEATHER_API_KEY:
        # Tra ve du lieu mock neu chua co API key
        return _mock_weather()

    url = "https://api.openweathermap.org/data/2.5/weather"
    params = {
        "lat": lat, "lon": lon,
        "appid": OPENWEATHER_API_KEY,
        "units": "metric",
        "lang": "vi",
    }

    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            resp = await client.get(url, params=params)
            resp.raise_for_status()
            raw = resp.json()

        data = {
            "temp_c": round(raw["main"]["temp"], 1),
            "feels_like_c": round(raw["main"]["feels_like"], 1),
            "humidity": raw["main"]["humidity"],
            "condition": raw["weather"][0]["main"],         # vd: "Rain", "Clear"
            "description": raw["weather"][0]["description"], # vd: "troi quang may"
            "icon": raw["weather"][0]["icon"],
            "wind_speed": raw["wind"]["speed"],
            "city": raw.get("name", ""),
            "source": "openweathermap",
        }
    except Exception:
        data = _mock_weather()

    # Luu cache
    _cache[cache_key] = (data, now + CACHE_TTL)
    return data


def _mock_weather() -> dict:
    """Du lieu thoi tiet gia lap khi chua co API key."""
    return {
        "temp_c": 30.0,
        "feels_like_c": 35.0,
        "humidity": 75,
        "condition": "Clear",
        "description": "troi quang (du lieu test)",
        "icon": "01d",
        "wind_speed": 3.5,
        "city": "Ho Chi Minh City",
        "source": "mock",
    }


def get_productivity_advice_from_weather(weather: dict) -> str:
    """Tao loi khuyen nang suat dua tren thoi tiet."""
    temp = weather.get("temp_c", 25)
    condition = weather.get("condition", "Clear")
    humidity = weather.get("humidity", 60)

    if temp >= 37:
        return (f"Nhiet do rat cao ({temp}°C)! Hay nghi ngoi nhieu hon, uong du nuoc "
                "va tranh lam viec trong phong khong co dieu hoa.")
    elif temp >= 33 and humidity > 70:
        return (f"Nong am ({temp}°C, do am {humidity}%). "
                "Giam cuong do 20%, tang thoi gian break len 10 phut.")
    elif condition in ("Rain", "Drizzle", "Thunderstorm"):
        return ("Troi mua - day la thoi diem tuyet voi de lam viec trong nha tap trung. "
                "Nhieu nghien cuu cho thay tieng mua giup tang kha nang tap trung!")
    elif condition == "Clear" and temp < 30:
        return (f"Thoi tiet dep ({temp}°C), mat me. Rat phu hop de lam viec hieu qua. "
                "Ban co the thu lam viec ngoai troi 15 phut de tang sang tao.")
    else:
        return f"Thoi tiet om ({temp}°C). Hay dam bao khong gian lam viec thoai mai."
