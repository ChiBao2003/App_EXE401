"""
application/context/context_service.py
Aggregates environmental context (Weather, Location, Calendar Density)
for prompt context injection.
"""
from typing import Dict, Any, Optional
import httpx


class ContextService:
    def __init__(self, weather_api_key: str = ""):
        self.weather_api_key = weather_api_key

    async def get_context(self, user_id: str, lat: Optional[float] = None, lon: Optional[float] = None, calendar_events_count: int = 4) -> Dict[str, Any]:
        weather_info = {"temperature": 29.0, "weather": "Sunny", "location": "Unknown"}
        
        if self.weather_api_key:
            try:
                async with httpx.AsyncClient(timeout=5.0) as client:
                    # 1. Tự động lấy vị trí qua IP nếu không có GPS từ App gửi lên
                    if lat is None or lon is None:
                        try:
                            ip_res = await client.get("https://api.ipify.org?format=json", timeout=3.0)
                            ip = ip_res.json().get("ip")
                            if ip:
                                geo_res = await client.get(f"http://ip-api.com/json/{ip}", timeout=3.0)
                                geo = geo_res.json()
                                if geo.get("status") == "success":
                                    lat = geo.get("lat")
                                    lon = geo.get("lon")
                        except Exception:
                            lat, lon = 10.7629, 106.682 # Fallback TP.HCM

                    # 2. Lấy thời tiết thật tại vị trí đó
                    if lat is not None and lon is not None:
                        res = await client.get(
                            f"https://api.openweathermap.org/data/2.5/weather?lat={lat}&lon={lon}&appid={self.weather_api_key}&units=metric"
                        )
                        if res.status_code == 200:
                            data = res.json()
                            weather_info["temperature"] = data["main"]["temp"]
                            weather_info["weather"] = data["weather"][0]["main"] if data.get("weather") else "Clear"
                            weather_info["location"] = data.get("name", "Unknown")
            except Exception as e:
                pass

        density = "Light" if calendar_events_count <= 2 else ("Medium" if calendar_events_count <= 5 else "Heavy")

        return {
            "temperature": weather_info["temperature"],
            "weather": weather_info["weather"],
            "location": weather_info["location"],
            "calendar_density": density,
            "calendar_events_count": calendar_events_count
        }
