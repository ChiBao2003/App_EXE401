"""
api/v1/auth_router.py - Endpoints xac thuc nguoi dung (Register / Login / Me)
"""
from fastapi import APIRouter, Depends, HTTPException, status
from motor.motor_asyncio import AsyncIOMotorDatabase
from datetime import datetime
import uuid
import asyncio
import re
from pydantic import BaseModel, Field
from google.oauth2 import id_token as google_id_token
from google.auth.transport import requests as google_requests
from google.auth.exceptions import TransportError
from pymongo.errors import DuplicateKeyError

from core.database import get_database
from core.config import GOOGLE_WEB_CLIENT_ID
from core.security import hash_password, verify_password, create_access_token, get_current_user_id
from domain.entities.user_entity import UserCreate, UserLogin, UserOut, TokenOut

router = APIRouter()


class ChangePasswordRequest(BaseModel):
    old_password: str
    new_password: str = Field(..., min_length=6)


class GoogleLoginRequest(BaseModel):
    id_token: str = Field(..., min_length=1)


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


<<<<<<< HEAD
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
            detail="Email này đã được đăng ký"
        )

    # Chống mạo danh: Biệt danh (display_name) phải là duy nhất
    clean_name = payload.display_name.strip()
    existing_name = await db["users"].find_one({"display_name": clean_name})
    if existing_name:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Biệt danh '{clean_name}' đã có người sử dụng. Vui lòng chọn biệt danh khác!"
        )

=======
def _new_user_doc(email: str, display_name: str, password: str | None = None,
                  google_sub: str | None = None, timezone: str = "Asia/Ho_Chi_Minh") -> dict:
>>>>>>> thang
    user_id = str(uuid.uuid4())
    now = datetime.utcnow().isoformat()
    doc = {
        "_id": user_id,
        "email": email,
        "display_name": display_name,
        "timezone": timezone,
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
    if password is not None:
        doc["password_hash"] = hash_password(password)
    if google_sub is not None:
        doc["google_sub"] = google_sub
    return doc


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

    if not 2 <= len(payload.display_name.strip()) <= 25:
        raise HTTPException(status_code=422, detail="Biet danh phai dai 2-25 ky tu")

    if await db["users"].find_one({"display_name": {
        "$regex": f"^{re.escape(payload.display_name.strip())}$", "$options": "i"
    }}):
        raise HTTPException(status_code=409, detail="Biet danh da duoc su dung")

    doc = _new_user_doc(payload.email, payload.display_name.strip(), payload.password,
                        timezone=payload.timezone)
    try:
        await db["users"].insert_one(doc)
    except DuplicateKeyError:
        raise HTTPException(status_code=409, detail="Email nay da duoc dang ky")

    token = create_access_token({"sub": doc["_id"]})
    return TokenOut(access_token=token, user=_format_user(doc))


@router.post("/login", response_model=TokenOut, summary="Dang nhap")
async def login(
    payload: UserLogin,
    db: AsyncIOMotorDatabase = Depends(get_database),
):
    """Dang nhap bang email + password, nhan JWT token."""
    user = await db["users"].find_one({"email": payload.email})
    if not user or not user.get("password_hash") or not verify_password(payload.password, user["password_hash"]):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email hoac mat khau khong dung"
        )

    token = create_access_token({"sub": user["_id"]})
    return TokenOut(access_token=token, user=_format_user(user))


@router.post("/google", response_model=TokenOut, summary="Dang nhap hoac dang ky voi Google")
async def google_login(
    payload: GoogleLoginRequest,
    db: AsyncIOMotorDatabase = Depends(get_database),
):
    if not GOOGLE_WEB_CLIENT_ID:
        raise HTTPException(status_code=503, detail="Dang nhap Google chua duoc cau hinh")
    try:
        claims = await asyncio.to_thread(
            google_id_token.verify_oauth2_token,
            payload.id_token,
            google_requests.Request(),
            GOOGLE_WEB_CLIENT_ID,
        )
    except (ValueError, TransportError):
        raise HTTPException(status_code=401, detail="Google token khong hop le hoac da het han")

    sub = claims.get("sub")
    email = claims.get("email")
    if not sub or not email or claims.get("email_verified") not in (True, "true"):
        raise HTTPException(status_code=401, detail="Tai khoan Google chua xac minh email")
    email = email.strip().lower()
    user = await db["users"].find_one({"google_sub": sub})
    if not user:
        if await db["users"].find_one({"email": email}):
            raise HTTPException(status_code=409, detail="Email da co tai khoan. Vui long dang nhap bang mat khau")
        name = (claims.get("name") or email.split("@")[0]).strip()
        user = _new_user_doc(email, name or email.split("@")[0], google_sub=sub)
        try:
            await db["users"].insert_one(user)
        except DuplicateKeyError:
            # Another concurrent Google login may have created this account.
            user = await db["users"].find_one({"google_sub": sub})
            if not user:
                raise HTTPException(status_code=409, detail="Email da co tai khoan")
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


@router.get("/verify-token", summary="Kiem tra phien dang nhap")
async def verify_token(
    user_id: str = Depends(get_current_user_id),
    db: AsyncIOMotorDatabase = Depends(get_database),
):
    if not await db["users"].find_one({"_id": user_id}, {"_id": 1}):
        raise HTTPException(status_code=401, detail="Phien dang nhap khong hop le")
    return {"valid": True}


@router.post("/change-password", summary="Doi mat khau")
async def change_password(
    payload: ChangePasswordRequest,
    user_id: str = Depends(get_current_user_id),
    db: AsyncIOMotorDatabase = Depends(get_database),
):
    user = await db["users"].find_one({"_id": user_id})
    if not user:
        raise HTTPException(status_code=404, detail="Nguoi dung khong ton tai")
    if not user.get("password_hash"):
        raise HTTPException(status_code=400, detail="Tai khoan Google khong co mat khau")
    if not verify_password(payload.old_password, user["password_hash"]):
        raise HTTPException(status_code=400, detail="Mat khau cu khong dung")
    result = await db["users"].update_one(
        {"_id": user_id, "password_hash": user["password_hash"]},
        {"$set": {"password_hash": hash_password(payload.new_password)}},
    )
    if result.matched_count == 0:
        raise HTTPException(status_code=409, detail="Mat khau da thay doi. Vui long thu lai")
    return {"message": "Doi mat khau thanh cong"}


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
