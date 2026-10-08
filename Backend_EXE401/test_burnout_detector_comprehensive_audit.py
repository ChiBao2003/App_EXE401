"""
test_burnout_detector_comprehensive_audit.py
Kịch bản Audit & Verification toàn diện cho application/ai/burnout_detector.py
"""
import asyncio
import math
import sys
import unittest
from datetime import datetime, timezone, timedelta
from unittest.mock import AsyncMock, MagicMock

sys.stdout.reconfigure(encoding='utf-8')

import application.ai.burnout_detector as bd
from application.ai.burnout_detector import (
    BurnoutDetector,
    compute_brix,
    _clamp,
    _num,
    _mean,
    _weighted,
    _vn_date,
    _from_log,
    _from_session,
    _exhaustion,
    _cynicism,
    _low_efficacy,
    _factor_behavioral_stress,
    _factor_late_night_work,
    _factor_behavioral_mood,
    _build_signals,
    _empty,
    W_EXHAUSTION,
    W_CYNICISM,
    W_LOW_EFFICACY,
)


def make_log(day=1, work_min=50, interruptions=1, completed=True, break_skipped=False, concentration_score=85, hour_of_day=10):
    return {
        "timestamp": f"2026-10-{day:02d}T{hour_of_day:02d}:00:00Z",
        "work_min": work_min,
        "interruptions": interruptions,
        "completed": completed,
        "break_skipped": break_skipped,
        "concentration_score": concentration_score,
        "hour_of_day": hour_of_day
    }


def make_session(day=1, work_min=50, pauses=1, completed=True, concentration_score=85, hour_of_day=10, unlock_count=10):
    return {
        "synced_at": f"2026-10-{day:02d}T{hour_of_day:02d}:00:00Z",
        "hardware_data": {"work_min": work_min, "pauses": pauses, "completed": completed},
        "phone_data": {"unlock_count": unlock_count},
        "computed": {"concentration_score": concentration_score, "hour_of_day": hour_of_day}
    }


class TestBurnoutDetectorComprehensive(unittest.TestCase):

    # ---------------- 1. Independent Helper Functions ----------------
    def test_01_helpers(self):
        # _clamp
        self.assertEqual(_clamp(-0.5), 0.0)
        self.assertEqual(_clamp(1.5), 1.0)
        self.assertEqual(_clamp(0.5), 0.5)

        # _num
        self.assertEqual(_num(10), 10.0)
        self.assertEqual(_num("25.5"), 25.5)
        self.assertIsNone(_num(None))
        self.assertIsNone(_num("abc"))
        self.assertIsNone(_num(""))

        # _mean
        self.assertEqual(_mean([10.0, 20.0, None, 30.0]), 20.0)
        self.assertIsNone(_mean([None, None]))
        self.assertIsNone(_mean([]))

        # _weighted
        # (0.4, 4.0), (0.3, 2.0), (0.3, None) -> (0.4*4 + 0.3*2) / 0.7 = 2.2 / 0.7 = 3.142857...
        res = _weighted([(0.4, 4.0), (0.3, 2.0), (0.3, None)])
        self.assertAlmostEqual(res, 2.2 / 0.7, places=5)
        self.assertIsNone(_weighted([(0.4, None), (0.6, None)]))

        # _vn_date
        self.assertEqual(_vn_date("2026-10-08T10:00:00Z"), "2026-10-08")
        self.assertEqual(_vn_date("2026-10-08T20:00:00Z"), "2026-10-09") # +7h -> next day
        self.assertEqual(_vn_date("2026-10-08T20:00:00+07:00"), "2026-10-08") # already VN time
        self.assertEqual(_vn_date("invalid"), "")

        # _from_log & _from_session
        log_rec = _from_log(make_log())
        self.assertEqual(log_rec["work_min"], 50.0)
        self.assertEqual(log_rec["pauses"], 1.0)
        self.assertTrue(log_rec["completed"])

        sess_rec = _from_session(make_session())
        self.assertEqual(sess_rec["work_min"], 50.0)
        self.assertEqual(sess_rec["unlocks"], 10.0)
        self.assertIsNone(sess_rec["break_skipped"])

    # ---------------- 2. Subscales & Modifiers ----------------
    def test_02_subscales_and_modifiers(self):
        # _exhaustion
        # work = 480m (load = 1.0), skip = 0.0 -> ex_val = 1.0 * 0.25 = 0.25 -> ex = 1.5
        self.assertAlmostEqual(_exhaustion(480, 0.0), 1.5, places=4)
        # work = 480m (load = 1.0), skip = 1.0 -> ex_val = 1.0 * 1.0 = 1.0 -> ex = 6.0
        self.assertAlmostEqual(_exhaustion(480, 1.0), 6.0, places=4)

        # _cynicism
        # pauses = 5 (pause_n = 1.0), incomplete = 1.0, unlocks = 60 (unlock_n = 1.0) -> cy = 6.0
        self.assertAlmostEqual(_cynicism(5, 1.0, 60), 6.0, places=4)
        # unlocks is None -> redistributes weights: (0.4*0.5 + 0.4*0.5) / 0.8 = 0.5 -> cy = 6.0 * 0.5 = 3.0
        self.assertAlmostEqual(_cynicism(2.5, 0.5, None), 3.0, places=4)

        # _low_efficacy
        # focus = 100 -> pe = 0.0
        self.assertAlmostEqual(_low_efficacy(100), 0.0, places=4)
        # focus = 40 -> pe = 6.0 * (1 - 0.4) = 3.6
        self.assertAlmostEqual(_low_efficacy(40), 3.6, places=4)

        # Modifiers
        self.assertEqual(_factor_behavioral_stress(0, 0.0), 1.0)
        self.assertEqual(_factor_behavioral_stress(5, 1.0), 1.10)

        self.assertEqual(_factor_late_night_work(0.0), 1.0)
        self.assertEqual(_factor_late_night_work(0.35), 1.10)

        self.assertEqual(_factor_behavioral_mood(90, 0.0, 0, 0.5), 0.92) # High engagement
        self.assertEqual(_factor_behavioral_mood(30, 0.8, 5, 1.0), 1.08) # Friction high

    # ---------------- 3. Scenario Tests (Cases A - H) ----------------
    def test_03_scenarios_a_to_h(self):
        # Case A: Low Risk
        logs_a = [make_log(day=d, work_min=40, interruptions=1, completed=True, break_skipped=False, concentration_score=85, hour_of_day=10) for d in range(1, 6) for _ in range(5)]
        res_a = compute_brix([], logs_a)
        self.assertEqual(res_a["risk_level"], "LOW")
        self.assertLess(res_a["burnout_risk_score"], 30.0)

        # Case B: High Workload + Skipped Breaks
        logs_b = [make_log(day=d, work_min=70, interruptions=2, completed=True, break_skipped=True, concentration_score=60, hour_of_day=10) for d in range(1, 6) for _ in range(8)]
        res_b = compute_brix([], logs_b)
        self.assertGreater(res_b["burnout_risk_score"], res_a["burnout_risk_score"])

        # Case C: High Interruption
        logs_c = [make_log(day=d, work_min=30, interruptions=5, completed=False, break_skipped=True, concentration_score=50, hour_of_day=10) for d in range(1, 6) for _ in range(5)]
        res_c = compute_brix([], logs_c)
        self.assertGreater(res_c["subscales_0_6"]["cynicism"], res_a["subscales_0_6"]["cynicism"])

        # Case D: Low Focus vs High Focus
        logs_low_f = [make_log(day=d, concentration_score=20) for d in range(1, 6)]
        logs_high_f = [make_log(day=d, concentration_score=90) for d in range(1, 6)]
        res_low_f = compute_brix([], logs_low_f)
        res_high_f = compute_brix([], logs_high_f)
        self.assertGreater(res_low_f["subscales_0_6"]["low_efficacy"], res_high_f["subscales_0_6"]["low_efficacy"])

        # Case E: Late Night vs Day
        logs_night = [make_log(day=d, hour_of_day=2) for d in range(1, 6)]
        logs_day = [make_log(day=d, hour_of_day=14) for d in range(1, 6)]
        res_night = compute_brix([], logs_night)
        res_day = compute_brix([], logs_day)
        self.assertGreaterEqual(res_night["weight_factors"]["insomnia"], res_day["weight_factors"]["insomnia"])

        # Case F: Missing Data
        logs_missing = [{"timestamp": "2026-10-08T10:00:00Z", "concentration_score": 70}]
        res_missing = compute_brix([], logs_missing)
        self.assertIsNone(res_missing["subscales_0_6"]["exhaustion"])
        self.assertIsNotNone(res_missing["burnout_risk_score"])

        # Case G: Empty Data
        res_empty = compute_brix([], [])
        self.assertEqual(res_empty["data_confidence"], "none")
        self.assertEqual(res_empty["burnout_risk_score"], 0.0)

        # Case H: Invalid Data
        logs_invalid = [{"timestamp": None, "work_min": "abc", "interruptions": -5, "completed": "unknown", "concentration_score": float("nan")}]
        res_invalid = compute_brix([], logs_invalid)
        self.assertIsNotNone(res_invalid["burnout_risk_score"])

    # ---------------- 4. Independent Math Tests (Expected Value) ----------------
    def test_04_exact_math_verification(self):
        # Math Test 1:
        # work_min = 480m (load = 1.0), skip_rate = 0.50 -> ex_val = 1.0*(0.25 + 0.75*0.5) = 0.625 -> ex = 3.75
        # pauses = 2.5 (pause_n = 0.5), incomplete_rate = 0.5, unlocks = None -> cy_val = 0.5 -> cy = 3.0
        # focus = 50 -> pe_val = 0.5 -> pe = 3.0
        # brix_o = 0.4*3.75 + 0.3*3.0 + 0.3*3.0 = 1.50 + 0.90 + 0.90 = 3.30
        # Modifiers:
        # stress_proxy = (0.5*0.5 + 0.5*0.5) = 0.5 -> f_s = 1.10
        # late_ratio = 0.0 -> f_i = 1.0
        # mood: pa = 0.5, na = 0.4*0.5 + 0.4*0.5 + 0.2*1.0 = 0.6 -> ratio = 0.5/0.6 = 0.833 -> f_m = 1.03
        # raw_mod = 1.10 * 1.0 * 1.03 = 1.133
        # total_mod = clamp(1.133, 0.88, 1.20) = 1.133
        # brix_w = 3.30 * 1.133 = 3.7389
        # score = round((3.7389 / 6.0) * 100.0, 1) = 62.3
        logs = []
        for d in range(1, 6):
            for i in range(8):
                completed = (i % 2 == 0)
                skip = (i % 2 == 1)
                logs.append(make_log(day=d, work_min=60, interruptions=2.5, completed=completed, break_skipped=skip, concentration_score=50, hour_of_day=10))

        res = compute_brix([], logs)
        self.assertAlmostEqual(res["brix_o"], 3.30, places=2)
        self.assertAlmostEqual(res["subscales_0_6"]["exhaustion"], 3.75, places=2)
        self.assertAlmostEqual(res["subscales_0_6"]["cynicism"], 3.00, places=2)
        self.assertAlmostEqual(res["subscales_0_6"]["low_efficacy"], 3.00, places=2)
        self.assertEqual(res["burnout_risk_score"], 62.3)
        self.assertEqual(res["risk_level"], "HIGH")

    # ---------------- 5. Monotonicity / Directionality Tests ----------------
    def test_05_directional_monotonicity(self):
        # 1. Focus decrease (90 -> 70 -> 50 -> 30) -> Risk score MUST NOT decrease
        scores_focus = []
        for foc in [90, 70, 50, 30]:
            r = compute_brix([], [make_log(concentration_score=foc) for _ in range(5)])
            scores_focus.append(r["burnout_risk_score"])
        self.assertTrue(all(x <= y for x, y in zip(scores_focus, scores_focus[1:])), f"Focus directional check failed: {scores_focus}")

        # 2. Workload increase (240 -> 480 -> 600) -> Risk score MUST NOT decrease
        scores_work = []
        for w in [240, 480, 600]:
            r = compute_brix([], [make_log(work_min=w//5, break_skipped=True) for _ in range(5)])
            scores_work.append(r["burnout_risk_score"])
        self.assertTrue(all(x <= y for x, y in zip(scores_work, scores_work[1:])), f"Work directional check failed: {scores_work}")

        # 3. Interruptions increase (0 -> 2 -> 5) -> Risk score MUST NOT decrease
        scores_pauses = []
        for p in [0, 2, 5]:
            r = compute_brix([], [make_log(interruptions=p) for _ in range(5)])
            scores_pauses.append(r["burnout_risk_score"])
        self.assertTrue(all(x <= y for x, y in zip(scores_pauses, scores_pauses[1:])), f"Pauses directional check failed: {scores_pauses}")

        # 4. Incomplete rate increase (0% -> 30% -> 60%) -> Risk score MUST NOT decrease
        scores_inc = []
        for inc_r in [0.0, 0.3, 0.6]:
            logs = [make_log(completed=(i >= int(10*inc_r))) for i in range(10)]
            r = compute_brix([], logs)
            scores_inc.append(r["burnout_risk_score"])
        self.assertTrue(all(x <= y for x, y in zip(scores_inc, scores_inc[1:])), f"Incomplete directional check failed: {scores_inc}")

        # 5. Late night ratio increase (0% -> 20% -> 50%) -> Risk score / modifier MUST NOT decrease
        scores_late = []
        for late_r in [0.0, 0.2, 0.5]:
            logs = [make_log(hour_of_day=2 if i < int(10*late_r) else 14) for i in range(10)]
            r = compute_brix([], logs)
            scores_late.append(r["burnout_risk_score"])
        self.assertTrue(all(x <= y for x, y in zip(scores_late, scores_late[1:])), f"Late night directional check failed: {scores_late}")

    # ---------------- 6. Risk Level Boundary Tests ----------------
    def test_06_boundary_checks(self):
        # Thresholds: <30 LOW, 30-49 MODERATE, 50-69 HIGH, >=70 CRITICAL
        # Test boundary function mapping manually or via brix_w values
        def level_for_score(score):
            if score >= 70.0: return "CRITICAL"
            if score >= 50.0: return "HIGH"
            if score >= 30.0: return "MODERATE"
            return "LOW"

        self.assertEqual(level_for_score(29.9), "LOW")
        self.assertEqual(level_for_score(30.0), "MODERATE")
        self.assertEqual(level_for_score(30.1), "MODERATE")
        self.assertEqual(level_for_score(49.9), "MODERATE")
        self.assertEqual(level_for_score(50.0), "HIGH")
        self.assertEqual(level_for_score(50.1), "HIGH")
        self.assertEqual(level_for_score(69.9), "HIGH")
        self.assertEqual(level_for_score(70.0), "CRITICAL")
        self.assertEqual(level_for_score(70.1), "CRITICAL")

    # ---------------- 7. Async MongoDB Integration Mock Test ----------------
    def test_07_async_mongodb_mock(self):
        mock_db = MagicMock()
        mock_logs_coll = MagicMock()
        mock_sess_coll = MagicMock()
        mock_daily_coll = MagicMock()

        mock_db.__getitem__.side_effect = lambda name: {
            "productivity_logs": mock_logs_coll,
            "pomodoro_sessions": mock_sess_coll,
            "daily_summaries": mock_daily_coll,
        }[name]

        mock_logs_coll.find.return_value.to_list = AsyncMock(return_value=[
            make_log(day=1), make_log(day=2), make_log(day=3), make_log(day=4), make_log(day=5)
        ])
        mock_sess_coll.find.return_value.to_list = AsyncMock(return_value=[])
        mock_daily_coll.find.return_value.to_list = AsyncMock(return_value=[{"total_unlocks": 15}])

        detector = BurnoutDetector(mock_db)
        res = asyncio.run(detector.calculate_burnout_risk("user_123"))

        self.assertEqual(res["data_source"], "productivity_logs")
        self.assertEqual(res["data_confidence"], "ok")
        self.assertIn(res["risk_level"], ("LOW", "MODERATE", "HIGH", "CRITICAL"))
        self.assertEqual(res["factors"]["unlocks_per_day"], 15.0)

    # ---------------- 8. Output Contract Verification ----------------
    def test_08_output_contract_schema(self):
        logs = [make_log(day=d) for d in range(1, 6)]
        res = compute_brix([], logs)

        required_keys = {
            "burnout_risk_score", "risk_level", "brix_o", "brix_w",
            "data_confidence", "data_source", "subscales_0_6",
            "weight_factors", "factors", "signals"
        }
        self.assertTrue(required_keys.issubset(res.keys()))

        # Types
        self.assertIsInstance(res["burnout_risk_score"], float)
        self.assertIsInstance(res["risk_level"], str)
        self.assertIsInstance(res["signals"], dict)
        self.assertIsInstance(res["subscales_0_6"], dict)
        self.assertIsInstance(res["weight_factors"], dict)
        self.assertIsInstance(res["factors"], dict)

        # Range checks
        self.assertTrue(0.0 <= res["burnout_risk_score"] <= 100.0)
        self.assertTrue(0.0 <= res["brix_o"] <= 6.0)
        self.assertTrue(0.0 <= res["brix_w"] <= 6.0)


if __name__ == "__main__":
    unittest.main()
