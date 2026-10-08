"""Unit test cho BRIX proxy. Chạy: python -m pytest test_burnout_brix.py -q  (hoặc python test_burnout_brix.py)"""
from application.ai import burnout_detector as bd
from application.ai.burnout_detector import compute_brix


def S(day, work, pauses, done, brk, foc):
    return {"synced_at": f"2026-10-{day:02d}T03:00:00",
            "hardware_data": {"work_min": work, "pauses": pauses, "completed": done, "take_break": brk},
            "computed": {"concentration_score": foc}}


def L(h, foc, work=25, pauses=0, done=True, skip=False):
    return {"hour_of_day": h, "concentration_score": foc, "work_min": work, "interruptions": pauses, "completed": done, "break_skipped": skip}


def test_weights_and_ranges():
    assert abs(bd.W_EXHAUSTION + bd.W_CYNICISM + bd.W_LOW_EFFICACY - 1.0) < 1e-9
    for r in (compute_brix([S(1, 25, 0, True, True, 85)] * 6, [L(10, 85)] * 6),
              compute_brix([S(1, 90, 9, False, False, 0)] * 30, [L(2, 0)] * 30, unlocks_per_day=999)):
        for v in r["subscales_0_6"].values():
            if v is not None:
                assert 0.0 <= v <= 6.0
        assert r["brix_w"] >= 0 and 0 <= r["burnout_risk_score"] <= 100


def test_healthy_is_low():
    r = compute_brix([S(d, 25, 0, True, True, 85) for d in range(1, 6) for _ in range(6)], [L(10, 85)] * 30)
    assert r["risk_level"] == "LOW" and r["data_confidence"] == "ok"


def test_overload_is_critical():
    r = compute_brix([S(d, 50, 4, False, False, 35) for d in range(1, 6) for _ in range(12)], [L(1, 35, work=50, pauses=4, done=False, skip=True)] * 60)
    assert r["risk_level"] == "CRITICAL" and r["burnout_risk_score"] >= 70.0


def test_no_data():
    r = compute_brix([], [])
    assert r["risk_level"] == "LOW" and r["data_confidence"] == "none" and r["burnout_risk_score"] == 0.0


def test_low_confidence_and_missing_fields():
    r = compute_brix([{"hardware_data": None}, {}, {"hardware_data": {"work_min": None, "pauses": "x"}}], [{}])
    assert r["data_confidence"] == "low" and r["risk_level"] in ("LOW", "MODERATE", "CRITICAL")


def test_cutoffs_from_paper():
    assert (bd.CUTOFF_MODERATE, bd.CUTOFF_HIGH) == (1.5, 3.5)


if __name__ == "__main__":
    for name, fn in list(globals().items()):
        if name.startswith("test_"):
            fn()
            print("PASS", name)
