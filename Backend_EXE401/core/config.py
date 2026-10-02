"""
core/config.py - Cau hinh tap trung cho toan bo Backend
Load tu file .env de de deploy, khong hardcode secrets.
"""
import os
from dotenv import load_dotenv

load_dotenv()

# ============================================================
# Database
# ============================================================
MONGO_URI: str = os.getenv("MONGO_URI", "mongodb://localhost:27017")
DATABASE_NAME: str = os.getenv("DATABASE_NAME", "Pomodoro_App")

# ============================================================
# JWT Auth
# ============================================================
SECRET_KEY: str = os.getenv("SECRET_KEY", "CHANGE_ME_IN_PRODUCTION_super_secret_key_2024")
ALGORITHM: str = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES: int = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "10080"))  # 7 ngay

# ============================================================
# External APIs
# ============================================================
OPENWEATHER_API_KEY: str = os.getenv("OPENWEATHER_API_KEY", "")
GEMINI_API_KEY: str = os.getenv("GEMINI_API_KEY", "")

# ============================================================
# MQTT Broker
# ============================================================
MQTT_BROKER_HOST: str = os.getenv("MQTT_BROKER_HOST", "localhost")
MQTT_BROKER_PORT: int = int(os.getenv("MQTT_BROKER_PORT", "1883"))

# ============================================================
# App
# ============================================================
APP_ENV: str = os.getenv("APP_ENV", "development")
DEBUG: bool = APP_ENV == "development"
