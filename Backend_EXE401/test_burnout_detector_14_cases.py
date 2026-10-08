"""
test_burnout_detector_14_cases.py
Bộ test 14 trường hợp bắt buộc cho Behavioral Burnout Risk Score / Index.
"""
import sys
import unittest

from application.ai.burnout_detector import compute_brix, W_EXHAUSTION, W_CYNICISM, W_LOW_EFFICACY

sys.stdout.reconfigure(encoding='utf-8')


def make_log(day=1, work_min=50, interruptions=1, completed=True, break_skipped=False, concentration_score=85, hour_of_day=10):
    return {
        "timestamp": f"2026-10-{day:02d}T{hour_of_day:02d}:00:00",
        "work_min": work_min,
        "interruptions": interruptions,
        "completed": completed,
        "break_skipped": break_skipped,
        "concentration_score": concentration_score,
        "hour_of_day": hour_of_day
    }


class TestBurnoutDetector14Cases(unittest.TestCase):

    def test_case_01_healthy_high_productivity(self):
        """1. Healthy high productivity (Case E: 480 min/day, focus 90, completion 95%, skipped_break 2%, pauses 0-1, late_night 0%).
        BẮT BUỘC: KHÔNG được tự động thành CRITICAL chỉ vì work_min = 480."""
        # 6 ngày x 8 phiên 60 phút = 480 phút/ngày
        logs = []
        for day in range(1, 7):
            for _ in range(8):
                logs.append(make_log(day=day, work_min=60, interruptions=0, completed=True, break_skipped=False, concentration_score=90, hour_of_day=10))
        # Cho 2% skipped break (2 phiên skipped trong 48 phiên)
        logs[0]["break_skipped"] = True

        res = compute_brix(sessions=[], logs=logs)
        self.assertEqual(res["risk_level"], "LOW")
        self.assertLess(res["burnout_risk_score"], 30.0)
        self.assertEqual(res["signals"]["workload"], "high")
        self.assertEqual(res["signals"]["recovery"], "good")
        self.assertEqual(res["signals"]["focus"], "high")

    def test_case_02_low_focus_only(self):
        """2. Low focus single signal -> KHÔNG được tự kết luận CRITICAL."""
        logs = [make_log(day=d, work_min=40, interruptions=1, completed=True, break_skipped=False, concentration_score=30, hour_of_day=14) for d in range(1, 6) for _ in range(4)]
        res = compute_brix(sessions=[], logs=logs)
        self.assertIn(res["risk_level"], ("LOW", "MODERATE"))
        self.assertLess(res["burnout_risk_score"], 50.0)

    def test_case_03_high_workload_only(self):
        """3. High workload single signal -> KHÔNG được tự kết luận CRITICAL."""
        logs = [make_log(day=d, work_min=60, interruptions=0, completed=True, break_skipped=False, concentration_score=85, hour_of_day=10) for d in range(1, 6) for _ in range(9)] # 540m/day
        res = compute_brix(sessions=[], logs=logs)
        self.assertIn(res["risk_level"], ("LOW", "MODERATE"))
        self.assertLess(res["burnout_risk_score"], 50.0)

    def test_case_04_high_skipped_breaks_only(self):
        """4. High skipped breaks single signal -> KHÔNG được tự kết luận CRITICAL."""
        logs = [make_log(day=d, work_min=30, interruptions=1, completed=True, break_skipped=True, concentration_score=85, hour_of_day=10) for d in range(1, 6) for _ in range(5)]
        res = compute_brix(sessions=[], logs=logs)
        self.assertIn(res["risk_level"], ("LOW", "MODERATE"))
        self.assertLess(res["burnout_risk_score"], 50.0)

    def test_case_05_high_incomplete_rate_only(self):
        """5. High incomplete rate single signal -> KHÔNG được tự kết luận CRITICAL."""
        logs = [make_log(day=d, work_min=30, interruptions=1, completed=False, break_skipped=False, concentration_score=85, hour_of_day=10) for d in range(1, 6) for _ in range(5)]
        res = compute_brix(sessions=[], logs=logs)
        self.assertIn(res["risk_level"], ("LOW", "MODERATE"))
        self.assertLess(res["burnout_risk_score"], 50.0)

    def test_case_06_high_interruptions_only(self):
        """6. High interruptions single signal -> KHÔNG được tự kết luận CRITICAL."""
        logs = [make_log(day=d, work_min=30, interruptions=6, completed=True, break_skipped=False, concentration_score=85, hour_of_day=10) for d in range(1, 6) for _ in range(5)]
        res = compute_brix(sessions=[], logs=logs)
        self.assertIn(res["risk_level"], ("LOW", "MODERATE"))
        self.assertLess(res["burnout_risk_score"], 50.0)

    def test_case_07_late_night_work_only(self):
        """7. Late-night work single signal -> KHÔNG được tự kết luận CRITICAL."""
        logs = [make_log(day=d, work_min=30, interruptions=1, completed=True, break_skipped=False, concentration_score=85, hour_of_day=2) for d in range(1, 6) for _ in range(5)]
        res = compute_brix(sessions=[], logs=logs)
        self.assertIn(res["risk_level"], ("LOW", "MODERATE"))
        self.assertLess(res["burnout_risk_score"], 50.0)

    def test_case_08_multiple_negative_signals_cases_c_and_d(self):
        """8. Multiple negative signals -> Case C (HIGH) và Case D (CRITICAL)."""
        # Case C: 560 min/day, focus 48, completion 55%, skipped_break 45%, pauses 4, late_night 35%
        c_logs = []
        for d in range(1, 6):
            for i in range(8): # ~560m
                completed = (i % 2 == 0)
                skip = (i % 2 == 1)
                hour = 2 if i < 3 else 14
                c_logs.append(make_log(day=d, work_min=70, interruptions=4, completed=completed, break_skipped=skip, concentration_score=48, hour_of_day=hour))
        res_c = compute_brix(sessions=[], logs=c_logs)
        self.assertIn(res_c["risk_level"], ("HIGH", "CRITICAL"))
        self.assertGreaterEqual(res_c["burnout_risk_score"], 50.0)

        # Case D: 650 min/day, focus 30, completion 35%, skipped_break 70%, pauses >= 5, late_night 50%
        d_logs = []
        for d in range(1, 6):
            for i in range(10): # ~650m
                completed = (i < 3)
                skip = (i >= 3)
                hour = 1 if i < 5 else 15
                d_logs.append(make_log(day=d, work_min=65, interruptions=5, completed=completed, break_skipped=skip, concentration_score=30, hour_of_day=hour))
        res_d = compute_brix(sessions=[], logs=d_logs)
        self.assertEqual(res_d["risk_level"], "CRITICAL")
        self.assertGreaterEqual(res_d["burnout_risk_score"], 70.0)

    def test_case_09_missing_focus(self):
        """9. Missing focus (focus field missing in logs)."""
        logs = [make_log(day=d, work_min=40, interruptions=1, completed=True, break_skipped=False, concentration_score=None, hour_of_day=10) for d in range(1, 6)]
        res = compute_brix(sessions=[], logs=logs)
        self.assertIsNone(res["subscales_0_6"]["low_efficacy"])
        self.assertIsNotNone(res["burnout_risk_score"])
        self.assertIn(res["risk_level"], ("LOW", "MODERATE", "HIGH", "CRITICAL"))

    def test_case_10_missing_unlock_data(self):
        """10. Missing unlock data (unlocks_per_day is None)."""
        logs = [make_log(day=d, work_min=40, interruptions=1, completed=True, break_skipped=False, concentration_score=80, hour_of_day=10) for d in range(1, 6)]
        res = compute_brix(sessions=[], logs=logs, unlocks_per_day=None)
        self.assertIsNone(res["factors"]["unlocks_per_day"])
        self.assertIsNotNone(res["subscales_0_6"]["cynicism"])

    def test_case_11_very_little_data(self):
        """11. Very little data (2 sessions) -> data_confidence == 'low'."""
        logs = [make_log(day=1, work_min=30), make_log(day=1, work_min=30)]
        res = compute_brix(sessions=[], logs=logs)
        self.assertEqual(res["data_confidence"], "low")
        self.assertEqual(res["factors"]["sessions_analyzed"], 2)

    def test_case_12_empty_database(self):
        """12. Empty database -> returns _empty() with data_confidence == 'none'."""
        res = compute_brix(sessions=[], logs=[])
        self.assertEqual(res["data_confidence"], "none")
        self.assertEqual(res["burnout_risk_score"], 0.0)
        self.assertEqual(res["risk_level"], "LOW")

    def test_case_13_all_signals_healthy(self):
        """13. All signals healthy (Case A: 300 min/day, focus 85, completion 92%, skipped_break 5%, pauses 1, late_night 2%)."""
        logs = []
        for d in range(1, 6):
            for i in range(5): # 300m/day
                completed = (i != 4)
                skip = (d == 1 and i == 0)
                logs.append(make_log(day=d, work_min=60, interruptions=1, completed=completed, break_skipped=skip, concentration_score=85, hour_of_day=10))
        res = compute_brix(sessions=[], logs=logs)
        self.assertEqual(res["risk_level"], "LOW")
        self.assertLess(res["burnout_risk_score"], 30.0)

    def test_case_14_burnout_policy_trigger(self):
        """14. Burnout >= 70 policy threshold check."""
        d_logs = []
        for d in range(1, 6):
            for i in range(10):
                d_logs.append(make_log(day=d, work_min=65, interruptions=5, completed=False, break_skipped=True, concentration_score=30, hour_of_day=1))
        res = compute_brix(sessions=[], logs=d_logs)
        self.assertGreaterEqual(res["burnout_risk_score"], 70.0)
        self.assertEqual(res["risk_level"], "CRITICAL")


if __name__ == "__main__":
    unittest.main()
