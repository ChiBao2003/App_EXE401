"""
core/security.py - He thong xac thuc JWT + Password Hashing
Dung bcrypt truc tiep va python-jose[cryptography]
"""
from datetime import datetime, timedelta
from typing import Optional

from jose import JWTError, jwt
import bcrypt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from motor.motor_asyncio import AsyncIOMotorDatabase

from core.config import SECRET_KEY, ALGORITHM, ACCESS_TOKEN_EXPIRE_MINUTES
from core.database import get_database

# ============================================================
# Password Hashing (dùng bcrypt trực tiếp, bỏ passlib)
# ============================================================
bearer_scheme = HTTPBearer(auto_error=False)


def hash_password(plain: str) -> str:
    """Ma hoa password bang bcrypt."""
    return bcrypt.hashpw(plain.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def verify_password(plain: str, hashed: str) -> bool:
    """Kiem tra password voi hash da luu."""
    return bcrypt.checkpw(plain.encode("utf-8"), hashed.encode("utf-8"))


# ============================================================
# JWT Token
# ============================================================
def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    """Tao JWT access token."""
    to_encode = data.copy()
    expire = datetime.utcnow() + (
        expires_delta or timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    to_encode["exp"] = expire
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)


def decode_token(token: str) -> dict:
    """Giai ma JWT, nem loi neu khong hop le."""
    try:
        return jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token khong hop le hoac da het han",
            headers={"WWW-Authenticate": "Bearer"},
        )


# ============================================================
# FastAPI Dependency - Lay current user tu token
# ============================================================
async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: AsyncIOMotorDatabase = Depends(get_database),
) -> dict:
    """
    FastAPI dependency: xac thuc Bearer token, tra ve user dict.
    Dung trong router: current_user = Depends(get_current_user)
    """
    if not credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Can Bearer token de truy cap",
        )
    payload = decode_token(credentials.credentials)
    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(status_code=401, detail="Token khong chua user_id")

    user = await db["users"].find_one({"_id": user_id})
    if not user:
        raise HTTPException(status_code=401, detail="Nguoi dung khong ton tai")
    return user


async def get_current_user_id(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
) -> str:
    """
    Nhe hon get_current_user: chi tra user_id tu token ma khong query DB.
    Dung khi chi can user_id ma khong can toan bo profile.
    """
    if not credentials:
        raise HTTPException(status_code=401, detail="Can Bearer token de truy cap")
    payload = decode_token(credentials.credentials)
    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(status_code=401, detail="Token khong chua user_id")
    return user_id
