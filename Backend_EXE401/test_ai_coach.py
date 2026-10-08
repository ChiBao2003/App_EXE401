import asyncio
import os
import sys
import json
import unittest
from unittest.mock import AsyncMock, patch, MagicMock
from pathlib import Path

# Fix Windows console UTF-8 output
sys.stdout.reconfigure(encoding='utf-8')

# Add project root to sys.path
sys.path.insert(0, str(Path(__file__).parent))

from application.ai.ai_coach_orchestrator import AICoachOrchestrator, _normalize_text

class TestAICoachOrchestrator(unittest.TestCase):
    
    def setUp(self):
        self.orchestrator = AICoachOrchestrator(api_key="test_dummy_key_123456789")
        self.digital_twin = {
            "user_id": "test_user",
            "total_sessions": 0,
            "stress_level": None,
            "efficiency": 0.0,
            "focus_score": 0.0,
            "burnout_risk_score": 20.0
        }
        self.context = {"temperature": 26.0}
        self.context_payload = {"ai_ranking": {}}

    def test_text_normalization(self):
        self.assertEqual(_normalize_text("helo!"), "helo")
        self.assertEqual(_normalize_text("Hello bạn"), "hello ban")
        self.assertEqual(_normalize_text("xin chào!"), "xin chao")
        self.assertEqual(_normalize_text("  ĐẶT   POMODORO  30/5  "), "dat pomodoro 305")

    def test_rule_based_greetings(self):
        for greeting in ["helo!", "Hello bạn", "xin chào", "hi coach"]:
            res = self.orchestrator._rule_based(self.digital_twin, self.context, self.context_payload, user_prompt=greeting)
            self.assertEqual(res["source"], "rule-based-v2")
            self.assertIn("POMO Coach", res["reply"])
            self.assertEqual(res["tool_calls"], [])

    def test_rule_based_zero_efficiency_handled_as_none(self):
        res = self.orchestrator._rule_based(self.digital_twin, self.context, self.context_payload, user_prompt="Phân tích năng suất")
        self.assertIn("Hiệu suất chưa có dữ liệu", res["reply"])
        self.assertIn("Tập trung chưa có dữ liệu", res["reply"])
        self.assertNotIn("0.0/100", res["reply"])

    def test_fallback_reason_included_when_no_api_key(self):
        orch_no_key = AICoachOrchestrator(api_key="")
        res = asyncio.run(orch_no_key.chat(
            user_id="u1",
            user_prompt="Xin chào",
            digital_twin=self.digital_twin,
            context=self.context,
            watch_status={}
        ))
        self.assertIn("fallback_reason", res)
        self.assertEqual(res["fallback_reason"], "GEMINI_API_KEY is empty or not configured")

    @patch("httpx.AsyncClient.post")
    def test_call_gemini_200_ok(self, mock_post):
        mock_resp = MagicMock()
        mock_resp.status_code = 200
        mock_resp.raise_for_status.return_value = None
        mock_resp.json.return_value = {
            "candidates": [
                {
                    "content": {"parts": [{"text": "Chào bạn, tôi là Gemini AI Coach!"}]},
                    "finishReason": "STOP"
                }
            ]
        }
        mock_post.return_value = mock_resp

        res = asyncio.run(self.orchestrator._call_gemini("test content", {}, []))
        self.assertEqual(res["reply"], "Chào bạn, tôi là Gemini AI Coach!")
        self.assertEqual(res["source"], "models/gemini-flash-lite-latest")

    @patch("httpx.AsyncClient.post")
    def test_call_gemini_400_bad_request_raises(self, mock_post):
        import httpx
        mock_resp = MagicMock()
        mock_resp.status_code = 400
        mock_resp.text = "Invalid JSON payload"
        
        req = httpx.Request("POST", "https://generativelanguage.googleapis.com")
        http_err = httpx.HTTPStatusError("400 Bad Request", request=req, response=mock_resp)
        mock_resp.raise_for_status.side_effect = http_err
        mock_post.return_value = mock_resp

        with self.assertRaises(httpx.HTTPStatusError):
            asyncio.run(self.orchestrator._call_gemini("test content", {}, []))

if __name__ == "__main__":
    unittest.main()
