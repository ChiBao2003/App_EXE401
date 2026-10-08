"""
test_api_coach_chat_endpoint.py
Test FastAPI endpoint POST /api/v1/ai/coach/chat with Dependency Overrides
"""
import asyncio
import json
import sys
import unittest
from unittest.mock import AsyncMock, MagicMock, patch

sys.stdout.reconfigure(encoding='utf-8')

from fastapi.testclient import TestClient
from main import app
from core.database import get_database
from core.security import get_current_user_id


def make_pomo_log(day=1, work_min=65, interruptions=5, completed=False, break_skipped=True, concentration_score=30, hour_of_day=1):
    return {
        "timestamp": f"2026-10-{day:02d}T{hour_of_day:02d}:00:00Z",
        "work_min": work_min,
        "interruptions": interruptions,
        "completed": completed,
        "break_skipped": break_skipped,
        "concentration_score": concentration_score,
        "hour_of_day": hour_of_day
    }


class TestAICoachChatEndpoint(unittest.TestCase):

    def setUp(self):
        self.mock_db = MagicMock()
        self.mock_logs = MagicMock()
        self.mock_sess = MagicMock()
        self.mock_daily = MagicMock()
        self.mock_history = MagicMock()

        self.mock_db.__getitem__.side_effect = lambda coll: {
            "productivity_logs": self.mock_logs,
            "pomodoro_sessions": self.mock_sess,
            "daily_summaries": self.mock_daily,
            "ai_chat_history": self.mock_history,
        }[coll]

        # Critical Burnout Logs
        critical_logs = [make_pomo_log(day=d) for d in range(1, 6) for _ in range(8)]
        self.mock_logs.find.return_value.to_list = AsyncMock(return_value=critical_logs)
        self.mock_logs.find.return_value.sort.return_value.to_list = AsyncMock(return_value=[])
        self.mock_sess.find.return_value.to_list = AsyncMock(return_value=[])
        self.mock_sess.find.return_value.sort.return_value.to_list = AsyncMock(return_value=[])
        self.mock_daily.find.return_value.to_list = AsyncMock(return_value=[{"total_unlocks": 50}])
        self.mock_daily.find_one = AsyncMock(return_value=None)
        self.mock_history.find.return_value.sort.return_value.limit.return_value.to_list = AsyncMock(return_value=[])
        self.mock_history.insert_one = AsyncMock(return_value=None)

        app.dependency_overrides[get_database] = lambda: self.mock_db
        app.dependency_overrides[get_current_user_id] = lambda: "test_user_id_123"

        self.client = TestClient(app)

    def tearDown(self):
        app.dependency_overrides.clear()

    @patch("httpx.AsyncClient.post")
    def test_post_chat_critical_burnout(self, mock_post):
        mock_resp = MagicMock()
        mock_resp.status_code = 200
        mock_resp.raise_for_status.return_value = None
        mock_resp.json.return_value = {
            "candidates": [
                {
                    "content": {
                        "parts": [
                            {
                                "functionCall": {
                                    "name": "set_pomodoro_cycle",
                                    "args": {"work_min": 15, "break_min": 15}
                                }
                            }
                        ]
                    },
                    "finishReason": "STOP"
                }
            ]
        }
        mock_post.return_value = mock_resp

        resp = self.client.post(
            "/api/v1/ai/coach/chat",
            json={
                "user_prompt": "Bắt đầu học Pomodoro",
                "watch_connected": True
            }
        )
        self.assertEqual(resp.status_code, 200)
        data = resp.json()

        # Verify response structure
        self.assertIn("reply", data)
        self.assertIn("tool_calls", data)
        self.assertIn("source", data)

        # Verify tool call was propagated to client
        tool_calls = data["tool_calls"]
        self.assertEqual(len(tool_calls), 1)
        self.assertEqual(tool_calls[0]["tool"], "set_pomodoro_cycle")
        self.assertEqual(tool_calls[0]["params"]["work_min"], 15)
        self.assertEqual(tool_calls[0]["params"]["break_min"], 15)


if __name__ == "__main__":
    unittest.main()
