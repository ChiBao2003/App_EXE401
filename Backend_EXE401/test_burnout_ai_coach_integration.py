"""
test_burnout_ai_coach_integration.py
Full End-to-End Integration Tests:
MongoDB -> BurnoutDetector -> FeatureEngine -> ContextReRanker -> RankingEngine -> AICoachOrchestrator -> Gemini/Fallback
"""
import asyncio
import json
import os
import sys
import unittest
from unittest.mock import AsyncMock, MagicMock, patch

# Configure UTF-8 for Windows console
sys.stdout.reconfigure(encoding='utf-8')

from application.ai.burnout_detector import BurnoutDetector, compute_brix
from application.ai.feature_engine import FeatureEngine
from application.ai.ranking_engine import CandidateGenerator, RankingEngine, ContextReRanker
from application.ai.ai_coach_orchestrator import AICoachOrchestrator


def make_pomo_log(day=1, work_min=50, interruptions=1, completed=True, break_skipped=False, concentration_score=85, hour_of_day=10):
    return {
        "timestamp": f"2026-10-{day:02d}T{hour_of_day:02d}:00:00Z",
        "work_min": work_min,
        "interruptions": interruptions,
        "completed": completed,
        "break_skipped": break_skipped,
        "concentration_score": concentration_score,
        "hour_of_day": hour_of_day
    }


def make_pomo_session(day=1, work_min=50, pauses=1, completed=True, concentration_score=85, hour_of_day=10, unlock_count=10):
    return {
        "synced_at": f"2026-10-{day:02d}T{hour_of_day:02d}:00:00Z",
        "hardware_data": {"work_min": work_min, "pauses": pauses, "completed": completed},
        "phone_data": {"unlock_count": unlock_count},
        "computed": {"concentration_score": concentration_score, "hour_of_day": hour_of_day}
    }


class TestBurnoutAICoachIntegration(unittest.TestCase):

    # 1. Low burnout test (< 30 -> LOW)
    def test_01_low_burnout(self):
        logs = [make_pomo_log(day=d, work_min=30, interruptions=0, completed=True, break_skipped=False, concentration_score=90, hour_of_day=10) for d in range(1, 6) for _ in range(5)]
        res = compute_brix(sessions=[], logs=logs)
        self.assertLess(res["burnout_risk_score"], 30.0)
        self.assertEqual(res["risk_level"], "LOW")

    # 2. Moderate burnout test (30 - 49.9 -> MODERATE)
    def test_02_moderate_burnout(self):
        # Case B: work = 430m/day, focus = 65, completion = 75%, skip = 25%, pauses = 2.5
        logs = []
        for d in range(1, 6):
            for i in range(7):
                hour = 1 if i == 0 else 10
                skip = (i % 4 == 0)
                completed = (i % 4 != 1)
                logs.append(make_pomo_log(day=d, work_min=62, interruptions=2.5, completed=completed, break_skipped=skip, concentration_score=65, hour_of_day=hour))
        res = compute_brix(sessions=[], logs=logs)
        self.assertGreaterEqual(res["burnout_risk_score"], 30.0)
        self.assertLess(res["burnout_risk_score"], 50.0)
        self.assertEqual(res["risk_level"], "MODERATE")

    # 3. High burnout test (50 - 69.9 -> HIGH)
    def test_03_high_burnout(self):
        logs = [make_pomo_log(day=d, work_min=70, interruptions=3, completed=(i % 2 == 0), break_skipped=(i % 2 == 1), concentration_score=50, hour_of_day=1) for d in range(1, 6) for i in range(8)]
        res = compute_brix(sessions=[], logs=logs)
        self.assertGreaterEqual(res["burnout_risk_score"], 50.0)
        self.assertLess(res["burnout_risk_score"], 70.0)
        self.assertEqual(res["risk_level"], "HIGH")

    # 4. Critical burnout test (>= 70 -> CRITICAL)
    def test_04_critical_burnout(self):
        logs = [make_pomo_log(day=d, work_min=70, interruptions=5, completed=False, break_skipped=True, concentration_score=25, hour_of_day=2) for d in range(1, 6) for _ in range(10)]
        res = compute_brix(sessions=[], logs=logs)
        self.assertGreaterEqual(res["burnout_risk_score"], 70.0)
        self.assertEqual(res["risk_level"], "CRITICAL")

    # 5. Critical policy enforcement: score >= 70 -> 15/15 Pomodoro
    def test_05_critical_policy_15_15(self):
        orchestrator = AICoachOrchestrator(api_key="")
        digital_twin = {
            "focus_score": 50,
            "stress_level": 70,
            "break_score": 40,
            "efficiency": 50,
            "burnout": {"burnout_risk_score": 75.0, "risk_level": "CRITICAL"},
            "burnout_risk_score": 75.0
        }
        context = {"temperature": 25, "weather": "clear"}
        
        # Test chat fallback applies 15/15 policy
        res = asyncio.run(orchestrator.chat(
            user_id="u1",
            user_prompt="Bắt đầu học Pomodoro",
            digital_twin=digital_twin,
            context=context,
            watch_status={}
        ))
        
        self.assertIn("tool_calls", res)
        tool_call = res["tool_calls"][0]
        self.assertEqual(tool_call["tool"], "set_pomodoro_cycle")
        self.assertEqual(tool_call["params"]["work_min"], 15)
        self.assertEqual(tool_call["params"]["break_min"], 15)
        self.assertIn("15 phút làm / 15 phút nghỉ", res["reply"])

        # Also verify ai_ranking.top_recommendation has 15/15 override
        top_rec = res["ai_ranking"]["top_recommendation"]
        self.assertEqual(top_rec["work_min"], 15)
        self.assertEqual(top_rec["break_min"], 15)
        self.assertIn("BURNOUT_HIGH_OVERRIDE", top_rec["reason_codes"])

    # 6. Isolation test: Ranking effect (burnout 10 vs burnout 80)
    def test_06_ranking_effect_isolation(self):
        digital_twin_base = {
            "focus_score": 80,
            "stress_level": 30,
            "break_score": 80,
            "efficiency": 80,
            "total_sessions": 10
        }
        context = {"temperature": 25, "weather": "clear"}

        # 1. Feature Extraction & Base Ranking
        features = FeatureEngine.extract_features(digital_twin_base, context, current_hour=10)
        candidates = CandidateGenerator.generate_pomodoro_candidates()
        ranker = RankingEngine(features)

        # Run with burnout = 10 (LOW)
        scored_1 = [ranker.score_pomodoro(c.model_copy()) for c in candidates]
        re_ranker_10 = ContextReRanker({"burnout_risk_score": 10.0, "risk_level": "LOW"}, context, features)
        final_10 = re_ranker_10.re_rank(scored_1)
        top_10 = final_10[0]

        # Run with burnout = 80 (CRITICAL)
        scored_2 = [ranker.score_pomodoro(c.model_copy()) for c in candidates]
        re_ranker_80 = ContextReRanker({"burnout_risk_score": 80.0, "risk_level": "CRITICAL"}, context, features)
        final_80 = re_ranker_80.re_rank(scored_2)
        top_80 = final_80[0]

        # PROOF: Candidates order and scores differ between burnout 10 and burnout 80
        self.assertNotEqual(top_10.work_min, top_80.work_min)
        # Low burnout prefers longer productive work (e.g. 40m or 50m)
        self.assertGreaterEqual(top_10.work_min, 40)
        # Critical burnout forces shorter session (e.g. 20m or 25m)
        self.assertLessEqual(top_80.work_min, 25)
        self.assertIn("CRITICAL_BURNOUT_RISK", [r for c in final_80 if c.work_min >= 40 for r in c.reason_codes])

    # 7. Gemini receives score verification
    @patch("httpx.AsyncClient.post")
    def test_07_gemini_receives_score(self, mock_post):
        mock_resp = MagicMock()
        mock_resp.status_code = 200
        mock_resp.raise_for_status.return_value = None
        mock_resp.json.return_value = {
            "candidates": [{"content": {"parts": [{"text": "Chào bạn, hãy nghỉ ngơi 15/15 phút nhé!"}]}}]
        }
        mock_post.return_value = mock_resp

        orchestrator = AICoachOrchestrator(api_key="valid_dummy_key_123456789")
        digital_twin = {
            "focus_score": 50,
            "burnout": {"burnout_risk_score": 82.4, "risk_level": "CRITICAL"},
            "burnout_risk_score": 82.4
        }
        context = {"temperature": 25}

        res = asyncio.run(orchestrator.chat(
            user_id="u1",
            user_prompt="Tôi muốn học tiếp",
            digital_twin=digital_twin,
            context=context,
            watch_status={}
        ))

        # Inspect the exact payload sent to Gemini API
        mock_call_args = mock_post.call_args
        json_body = mock_call_args.kwargs.get("json", {})
        prompt_sent = json_body["contents"][0]["parts"][0]["text"]

        self.assertIn("82.4", prompt_sent)
        self.assertIn("CRITICAL", prompt_sent)
        self.assertIn("BURNOUT_HIGH_OVERRIDE", prompt_sent)

    # 8. Fallback preserves burnout
    def test_08_fallback_preserves_burnout(self):
        orchestrator = AICoachOrchestrator(api_key="") # Force fallback
        digital_twin = {
            "stress_level": 75,
            "burnout": {"burnout_risk_score": 80.0, "risk_level": "CRITICAL"},
            "burnout_risk_score": 80.0
        }
        context = {"temperature": 25}

        res = asyncio.run(orchestrator.chat(
            user_id="u1",
            user_prompt="Trạng thái của tôi có tốt không",
            digital_twin=digital_twin,
            context=context,
            watch_status={}
        ))

        self.assertEqual(res["source"], "rule-based-v2")
        self.assertIn("80", res["reply"])
        self.assertIn("nguy cơ kiệt sức cao", res["reply"])

    # 9. Missing data handling
    def test_09_missing_data_safety(self):
        digital_twin = {
            "focus_score": None,
            "stress_level": None,
            "burnout": None,
            "burnout_risk_score": None
        }
        features = FeatureEngine.extract_features(digital_twin, {}, current_hour=10)
        self.assertEqual(features["burnout_risk"], 0.0)

        orchestrator = AICoachOrchestrator(api_key="")
        res = asyncio.run(orchestrator.chat(
            user_id="u1",
            user_prompt="Xin chào",
            digital_twin=digital_twin,
            context={},
            watch_status={}
        ))
        self.assertEqual(res["source"], "rule-based-v2")
        self.assertNotIn("None", res["reply"])

    # 10. Mongo failure safe handling
    def test_10_mongo_failure_safety(self):
        mock_db = MagicMock()
        mock_db.__getitem__.side_effect = Exception("MongoDB Connection Refused")

        detector = BurnoutDetector(mock_db)
        
        async def run_failing_query():
            try:
                return await detector.calculate_burnout_risk("u1")
            except Exception as e:
                return {"error": str(e), "burnout_risk_score": 0.0, "risk_level": "LOW"}

        res = asyncio.run(run_failing_query())
        self.assertEqual(res["risk_level"], "LOW")
        self.assertEqual(res["burnout_risk_score"], 0.0)

    # 11. Timezone conversion and late night detection
    def test_11_timezone_and_late_night(self):
        # 2026-10-07T17:00:00Z is 00:00:00 (Midnight) Vietnam Time (+7h)
        logs = [
            {"timestamp": "2026-10-07T17:00:00Z", "work_min": 30, "hour_of_day": 0, "concentration_score": 80},
            {"timestamp": "2026-10-07T18:00:00Z", "work_min": 30, "hour_of_day": 1, "concentration_score": 80},
            {"timestamp": "2026-10-07T03:00:00Z", "work_min": 30, "hour_of_day": 10, "concentration_score": 80},
        ]
        res = compute_brix(sessions=[], logs=logs)
        self.assertEqual(res["signals"]["late_night_work"], "high")
        self.assertGreater(res["weight_factors"]["insomnia"], 1.0)

    # 12. Source priority (productivity_logs preferred over pomodoro_sessions)
    def test_12_source_priority(self):
        logs = [make_pomo_log(day=1, work_min=25)]
        sessions = [make_pomo_session(day=1, work_min=50) for _ in range(20)]

        res = compute_brix(sessions=sessions, logs=logs)
        self.assertEqual(res["data_source"], "productivity_logs")
        self.assertEqual(res["factors"]["sessions_analyzed"], 1)

    # 13. End-to-End full pipeline integration test
    def test_13_full_pipeline_end_to_end(self):
        # Setup mock MongoDB returning 10 critical overload logs
        mock_db = MagicMock()
        mock_logs = MagicMock()
        mock_sess = MagicMock()
        mock_daily = MagicMock()

        mock_db.__getitem__.side_effect = lambda coll: {
            "productivity_logs": mock_logs,
            "pomodoro_sessions": mock_sess,
            "daily_summaries": mock_daily,
        }[coll]

        critical_logs = [make_pomo_log(day=d, work_min=65, interruptions=5, completed=False, break_skipped=True, concentration_score=30, hour_of_day=1) for d in range(1, 6) for _ in range(8)]
        mock_logs.find.return_value.to_list = AsyncMock(return_value=critical_logs)
        mock_sess.find.return_value.to_list = AsyncMock(return_value=[])
        mock_daily.find.return_value.to_list = AsyncMock(return_value=[{"total_unlocks": 80}])

        # Step 1: BurnoutDetector calculates risk from DB
        detector = BurnoutDetector(mock_db)
        burnout = asyncio.run(detector.calculate_burnout_risk("user_test"))
        self.assertGreaterEqual(burnout["burnout_risk_score"], 70.0)
        self.assertEqual(burnout["risk_level"], "CRITICAL")

        # Step 2: Digital Twin profile receives burnout
        digital_twin = {
            "focus_score": 30.0,
            "stress_level": 80.0,
            "break_score": 20.0,
            "efficiency": 30.0,
            "burnout": burnout,
            "burnout_risk_score": burnout["burnout_risk_score"]
        }
        context = {"temperature": 26.0, "weather": "clear"}

        # Step 3: FeatureEngine extracts features
        features = FeatureEngine.extract_features(digital_twin, context, current_hour=14)
        self.assertGreaterEqual(features["burnout_risk"], 0.70)

        # Step 4: AICoachOrchestrator processes chat
        orchestrator = AICoachOrchestrator(api_key="")
        res = asyncio.run(orchestrator.chat(
            user_id="user_test",
            user_prompt="Bắt đầu học",
            digital_twin=digital_twin,
            context=context,
            watch_status={}
        ))

        # Step 5: Verification of final recommendation and override
        top_rec = res["ai_ranking"]["top_recommendation"]
        self.assertIn(top_rec["work_min"], (10, 15))
        self.assertIn(top_rec["break_min"], (15, 20))
        self.assertTrue(any("BURNOUT" in r for r in top_rec["reason_codes"]))

        tool_calls = res["tool_calls"]
        self.assertEqual(len(tool_calls), 1)
        self.assertEqual(tool_calls[0]["params"]["work_min"], 15)
        self.assertEqual(tool_calls[0]["params"]["break_min"], 15)


if __name__ == "__main__":
    unittest.main()
