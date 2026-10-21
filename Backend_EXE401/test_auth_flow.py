"""Focused API checks for registration, session verification and password change."""
from fastapi import FastAPI
from fastapi.testclient import TestClient
from unittest.mock import patch

from api.v1.auth_router import router
from core.database import get_database


class Users:
    def __init__(self):
        self.docs = {}

    async def find_one(self, query, projection=None):
        for doc in self.docs.values():
            if all(doc.get(key) == value for key, value in query.items()):
                return doc
        return None

    async def insert_one(self, doc):
        self.docs[doc["_id"]] = doc

    async def update_one(self, query, update):
        doc = await self.find_one(query)
        if doc:
            doc.update(update["$set"])
        return type("Result", (), {"matched_count": int(doc is not None)})()


def test_auth_flow():
    users = Users()
    app = FastAPI()
    app.include_router(router, prefix="/api/v1/auth")
    app.dependency_overrides[get_database] = lambda: {"users": users}
    client = TestClient(app)
    base = "/api/v1/auth"

    registered = client.post(f"{base}/register", json={
        "email": "auth@example.com", "password": "oldpass",
        "display_name": "Auth User",
    })
    assert registered.status_code == 201
    token = registered.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    assert client.get(f"{base}/verify-token", headers=headers).json() == {"valid": True}
    assert client.get(f"{base}/verify-token").status_code == 401
    assert client.get(f"{base}/verify-token", headers={"Authorization": "Bearer invalid"}).status_code == 401

    duplicate = client.post(f"{base}/register", json={
        "email": "auth@example.com", "password": "oldpass",
        "display_name": "Auth User",
    })
    assert duplicate.status_code == 409
    assert isinstance(duplicate.json()["detail"], str)

    wrong = client.post(f"{base}/change-password", headers=headers, json={
        "old_password": "incorrect", "new_password": "newpass",
    })
    assert wrong.status_code == 400
    assert isinstance(wrong.json()["detail"], str)
    short = client.post(f"{base}/change-password", headers=headers, json={
        "old_password": "oldpass", "new_password": "short",
    })
    assert short.status_code == 422
    changed = client.post(f"{base}/change-password", headers=headers, json={
        "old_password": "oldpass", "new_password": "newpass",
    })
    assert changed.status_code == 200
    assert client.post(f"{base}/login", json={
        "email": "auth@example.com", "password": "oldpass",
    }).status_code == 401
    assert client.post(f"{base}/login", json={
        "email": "auth@example.com", "password": "newpass",
    }).status_code == 200


def test_google_registration_and_login():
    users = Users()
    app = FastAPI()
    app.include_router(router, prefix="/api/v1/auth")
    app.dependency_overrides[get_database] = lambda: {"users": users}
    client = TestClient(app)
    url = "/api/v1/auth/google"
    claims = {
        "sub": "google-user-123",
        "email": "google@example.com",
        "email_verified": True,
        "name": "Google User",
    }
    with patch("api.v1.auth_router.GOOGLE_WEB_CLIENT_ID", "test-client-id"), \
         patch("api.v1.auth_router.google_id_token.verify_oauth2_token", return_value=claims):
        first = client.post(url, json={"id_token": "signed-google-token"})
        second = client.post(url, json={"id_token": "signed-google-token"})
    assert first.status_code == 200
    assert second.status_code == 200
    assert len(users.docs) == 1
    assert first.json()["user"]["id"] == second.json()["user"]["id"]
    assert client.post("/api/v1/auth/login", json={
        "email": "google@example.com", "password": "anything",
    }).status_code == 401
    assert client.post("/api/v1/auth/change-password", json={
        "old_password": "anything", "new_password": "newpass",
    }, headers={"Authorization": f"Bearer {first.json()['access_token']}"}).status_code == 400


def test_google_rejects_invalid_token_and_existing_email():
    users = Users()
    app = FastAPI()
    app.include_router(router, prefix="/api/v1/auth")
    app.dependency_overrides[get_database] = lambda: {"users": users}
    client = TestClient(app)
    client.post("/api/v1/auth/register", json={
        "email": "existing@example.com", "password": "oldpass",
        "display_name": "Existing User",
    })
    with patch("api.v1.auth_router.GOOGLE_WEB_CLIENT_ID", "test-client-id"), \
         patch("api.v1.auth_router.google_id_token.verify_oauth2_token", side_effect=ValueError):
        invalid = client.post("/api/v1/auth/google", json={"id_token": "invalid"})
    assert invalid.status_code == 401
    assert isinstance(invalid.json()["detail"], str)
    with patch("api.v1.auth_router.GOOGLE_WEB_CLIENT_ID", "test-client-id"), \
         patch("api.v1.auth_router.google_id_token.verify_oauth2_token", return_value={
             "sub": "another-google-user", "email": "existing@example.com",
             "email_verified": True,
         }):
        conflict = client.post("/api/v1/auth/google", json={"id_token": "valid"})
    assert conflict.status_code == 409
    assert isinstance(conflict.json()["detail"], str)
