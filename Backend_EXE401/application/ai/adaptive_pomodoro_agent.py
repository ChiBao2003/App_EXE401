"""
application/ai/adaptive_pomodoro_agent.py
Q-Learning Agent cho Adaptive Pomodoro Scheduling.

State  : (hour_bin, conc_bin, completion_bin, break_skipped, task_type)
Action : (work_min, break_min) pairs
Reward : f(completion_rate, concentration_score, interruptions, break_skipped)

Q-table duoc persist trong MongoDB collection "ai_q_tables"
de khong mat hoc sau khi restart server.
"""
import math
import random
import json
from typing import Optional
from motor.motor_asyncio import AsyncIOMotorDatabase

from domain.entities.productivity_entity import AIRecommendation, SessionFeedback

# ============================================================
# Tap hanh dong (work_min, break_min)
# ============================================================
ACTIONS = [
    (20, 5), (25, 5), (30, 7),
    (35, 8), (40, 10), (45, 12), (50, 15)
]

# ============================================================
# Hyperparameters
# ============================================================
ALPHA = 0.15     # Learning rate
GAMMA = 0.9      # Discount factor
EPSILON = 0.12   # Exploration rate (12% ngau nhien)


def _encode_state(hour: int, concentration: float,
                  completion_rate: float, break_skipped: bool,
                  task_type: str) -> str:
    """
    Bien lien tuc thanh key string de lam chi muc Q-table.
    hour_bin: 0-5 (moi bin la 4 gio)
    conc_bin: 0=thap(<34), 1=trung(34-67), 2=cao(>67)
    comp_bin: 0=thap(<50), 1=cao(>=50)
    """
    hour_bin = min(hour // 4, 5)
    conc_bin = 0 if concentration < 34 else (1 if concentration < 68 else 2)
    comp_bin = 0 if completion_rate < 50 else 1
    task_key = task_type[:4].lower()  # vd: "codi", "read", "meet", "gene"
    return f"{hour_bin}_{conc_bin}_{comp_bin}_{int(break_skipped)}_{task_key}"


def _calculate_reward(completion_rate: float, concentration_score: float,
                      interruptions: int, break_skipped: bool) -> float:
    """
    Ham phan thuong sau moi phien:
    +50  neu hoan thanh tot
    +40  neu tap trung cao
    -5   moi lan bi ngat
    -15  neu bo qua break (lau dai gay burnout)
    """
    reward = (completion_rate / 100.0) * 50.0
    reward += (concentration_score / 100.0) * 40.0
    reward -= interruptions * 5.0
    reward -= 15.0 if break_skipped else 0.0
    return max(-60.0, min(100.0, reward))


class AdaptivePomodoroAgent:
    """
    Q-Learning agent per user.
    Moi user co Q-table rieng trong MongoDB.
    """

    def __init__(self, user_id: str, db: AsyncIOMotorDatabase):
        self.user_id = user_id
        self.db = db
        self._q: dict = {}   # state -> list of q-values (len = len(ACTIONS))
        self._loaded = False

    async def _load(self):
        """Tai Q-table tu MongoDB."""
        if self._loaded:
            return
        doc = await self.db["ai_q_tables"].find_one({"user_id": self.user_id})
        if doc and "q_table" in doc:
            self._q = json.loads(doc["q_table"])
        self._loaded = True

    async def _save(self):
        """Luu Q-table vao MongoDB (upsert)."""
        await self.db["ai_q_tables"].update_one(
            {"user_id": self.user_id},
            {"$set": {"q_table": json.dumps(self._q), "user_id": self.user_id}},
            upsert=True,
        )

    def _get_q(self, state: str):
        if state not in self._q:
            # ── Cold Start Fix: Heuristic Bias Initialization ──
            # Thay vì khởi tạo toàn 0.0 (luôn chọn index 0 = 20/5),
            # ta "mớm" kiến thức chuyên gia dựa trên mức tập trung (conc_bin)
            # trong chuỗi state: "hourBin_concBin_compBin_skipBin_taskKey"
            parts = state.split('_')
            conc_bin = int(parts[1]) if len(parts) > 1 else 1

            q_init = [0.0] * len(ACTIONS)
            # ACTIONS: 0(20/5), 1(25/5), 2(30/7), 3(35/8), 4(40/10), 5(45/12), 6(50/15)
            if conc_bin == 2:    # Tập trung CAO  → ưu tiên phiên dài
                q_init[4] = 5.0  # (40, 10)
                q_init[5] = 3.0  # (45, 12)
                q_init[3] = 1.5  # (35, 8)
            elif conc_bin == 1:  # Tập trung TRUNG BÌNH → phiên tiêu chuẩn
                q_init[1] = 5.0  # (25, 5)
                q_init[2] = 3.0  # (30, 7)
                q_init[3] = 1.5  # (35, 8)
            else:                # Tập trung THẤP → phiên ngắn để phục hồi
                q_init[0] = 5.0  # (20, 5)
                q_init[1] = 2.0  # (25, 5)

            self._q[state] = q_init
        return self._q[state]

    async def recommend(self, hour: int, concentration_score: float,
                        completion_rate: float, break_skipped: bool,
                        task_type: str = "general") -> AIRecommendation:
        """
        Lay goi y chuyen Pomodoro tiep theo dua tren Q-Learning.
        Epsilon-greedy: 12% kham pha ngau nhien, 88% khai thac Q-table.
        """
        await self._load()

        state = _encode_state(hour, concentration_score, completion_rate,
                               break_skipped, task_type)
        q_vals = self._get_q(state)

        if random.random() < EPSILON:
            action_idx = random.randint(0, len(ACTIONS) - 1)
            confidence = 0.5
        else:
            action_idx = int(q_vals.index(max(q_vals)))
            max_q = max(q_vals)
            min_q = min(q_vals)
            confidence = 0.6 + 0.4 * ((max_q - min_q) / (abs(max_q) + 1))
            confidence = round(min(confidence, 0.99), 2)

        work_min, break_min = ACTIONS[action_idx]

        # Tao reason
        if concentration_score >= 68:
            reason = (f"Diem tap trung cao ({concentration_score:.0f}/100) "
                      f"-> Lam {work_min} phut, nghi {break_min} phut")
        elif concentration_score < 34:
            reason = (f"Diem tap trung thap ({concentration_score:.0f}/100) "
                      f"-> Giam xuong {work_min} phut de phuc hoi nang luong")
        elif break_skipped:
            reason = (f"Ban da bo qua break -> Nghi {break_min} phut la quan trong! "
                      f"Chu ky nay: {work_min}/{break_min}")
        else:
            reason = (f"Hieu suat on dinh -> Giu chu ky {work_min} phut lam / "
                      f"{break_min} phut nghi")

        return AIRecommendation(
            work_min=work_min,
            break_min=break_min,
            reason=reason,
            confidence=confidence,
            source="q_learning",
        )

    async def update(self, feedback: SessionFeedback):
        """
        Cap nhat Q-table sau khi phien ket thuc (online learning).
        """
        await self._load()

        state = _encode_state(
            feedback.hour_of_day, feedback.concentration_score,
            feedback.completion_rate, feedback.break_skipped, feedback.task_type
        )

        # Tim action index gan nhat voi (work_min, break_min) da dung
        action_idx = 0
        min_dist = float("inf")
        for i, (w, b) in enumerate(ACTIONS):
            dist = abs(w - feedback.work_min) + abs(b - feedback.break_min)
            if dist < min_dist:
                min_dist = dist
                action_idx = i

        reward = _calculate_reward(
            feedback.completion_rate, feedback.concentration_score,
            feedback.interruptions, feedback.break_skipped
        )

        # Tinh next_state (gia su sau session focus van duy tri)
        next_concentration = min(100, feedback.concentration_score + reward * 0.1)
        next_state = _encode_state(
            (feedback.hour_of_day + 1) % 24, next_concentration,
            feedback.completion_rate, False, feedback.task_type
        )

        # Q-update
        q_curr = self._get_q(state)
        q_next = self._get_q(next_state)
        q_curr[action_idx] = q_curr[action_idx] + ALPHA * (
            reward + GAMMA * max(q_next) - q_curr[action_idx]
        )

        await self._save()
        return {"reward": round(reward, 2), "state": state, "action_idx": action_idx}
