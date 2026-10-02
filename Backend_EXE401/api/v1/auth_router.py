"""
api/v1/auth_router.py - Endpoints xac thuc nguoi dung (Register / Login / Me)
"""
from fastapi import APIRouter, Depends, HTTPException, status
from motor.motor_asyncio import AsyncIOMotorDatabase
from datetime import datetime
import uuid

from core.database import get_database
from core.security import hash_password, verify_password, create_access_token, get_current_user_id
from domain.entities.user_entity import UserCreate, UserLogin, UserOut, TokenOut

router = APIRouter()


def _format_user(doc: dict) -> UserOut:
    return UserOut(
        id=doc["_id"],
        email=doc["email"],
        display_name=doc["display_name"],
        timezone=doc.get("timezone", "Asia/Ho_Chi_Minh"),
        created_at=doc.get("created_at", ""),
        preferences=doc.get("preferences", {}),
        digital_twin=doc.get("digital_twin", {}),
    )


@router.post("/register", response_model=TokenOut, status_code=201,
             summary="Dang ky tai khoan moi")
async def register(
    payload: UserCreate,
    db: AsyncIOMotorDatabase = Depends(get_database),
):
    """Tao tai khoan moi. Email phai chua duoc su dung."""
    existing = await db["users"].find_one({"email": payload.email})
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Email nay da duoc dang ky"
        )

    user_id = str(uuid.uuid4())
    now = datetime.utcnow().isoformat()
    doc = {
        "_id": user_id,
        "email": payload.email,
        "password_hash": hash_password(payload.password),
        "display_name": payload.display_name,
        "timezone": payload.timezone,
        "created_at": now,
        "preferences": {
            "theme": "dark",
            "notification_enabled": True,
            "work_start_hour": 8,
            "work_end_hour": 17,
        },
        "digital_twin": {
            "productivity_profile": "unknown",
            "focus_score_avg": 0.0,
            "optimal_work_duration": 25,
            "optimal_break_duration": 5,
            "peak_hours": [],
            "burnout_risk_score": 0.0,
            "last_updated": now,
        },
    }
    await db["users"].insert_one(doc)

    token = create_access_token({"sub": user_id})
    return TokenOut(access_token=token, user=_format_user(doc))


@router.post("/login", response_model=TokenOut, summary="Dang nhap")
async def login(
    payload: UserLogin,
    db: AsyncIOMotorDatabase = Depends(get_database),
):
    """Dang nhap bang email + password, nhan JWT token."""
    user = await db["users"].find_one({"email": payload.email})
    if not user or not verify_password(payload.password, user["password_hash"]):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email hoac mat khau khong dung"
        )

    token = create_access_token({"sub": user["_id"]})
    return TokenOut(access_token=token, user=_format_user(user))


@router.get("/me", response_model=UserOut, summary="Lay thong tin tai khoan hien tai")
async def me(
    user_id: str = Depends(get_current_user_id),
    db: AsyncIOMotorDatabase = Depends(get_database),
):
    """Tra ve thong tin nguoi dung dang dang nhap (can Bearer token)."""
    user = await db["users"].find_one({"_id": user_id})
    if not user:
        raise HTTPException(status_code=404, detail="Nguoi dung khong ton tai")
    return _format_user(user)


@router.put("/me/preferences", summary="Cap nhat cai dat ca nhan")
async def update_preferences(
    preferences: dict,
    user_id: str = Depends(get_current_user_id),
    db: AsyncIOMotorDatabase = Depends(get_database),
):
    """Cap nhat preferences cua nguoi dung (theme, gio lam, etc.)."""
    await db["users"].update_one(
        {"_id": user_id},
        {"$set": {"preferences": preferences}}
    )
    return {"status": "ok", "message": "Cap nhat thanh cong"}
