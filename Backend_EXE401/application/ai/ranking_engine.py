"""
application/ai/ranking_engine.py
Personalized Ranking Engine for generating and evaluating AI Candidates.
Uses Rule-based MVP approach but structured to allow ML upgrades.
"""
from typing import List, Dict, Any, Tuple
from pydantic import BaseModel

# Available Pomodoro Lengths (work_min, break_min)
POMODORO_CANDIDATES = [
    (20, 5), (25, 5), (30, 5), (40, 10), (50, 10)
]

class RecommendationCandidate(BaseModel):
    candidate_type: str = "pomodoro"
    work_min: int
    break_min: int
    base_score: float = 0.0
    final_score: float = 0.0
    reason_codes: List[str] = []
    confidence: float = 0.0


class CandidateGenerator:
    @staticmethod
    def generate_pomodoro_candidates() -> List[RecommendationCandidate]:
        candidates = []
        task_types = ["coding", "reading", "meeting", "general"]
        for t_type in task_types:
            for w, b in POMODORO_CANDIDATES:
                candidates.append(RecommendationCandidate(
                    candidate_type=t_type,
                    work_min=w,
                    break_min=b
                ))
        return candidates


class RankingEngine:
    """
    MVP Weighted Ranking Engine.
    Score = 0.4 * FocusMatch + 0.3 * FatigueFit + 0.3 * Efficiency
    """
    def __init__(self, features: Dict[str, float]):
        self.features = features

    def score_pomodoro(self, candidate: RecommendationCandidate) -> RecommendationCandidate:
        work_min = candidate.work_min
        t_type = candidate.candidate_type
        
        # Features
        global_focus_score = self.features.get("focus_score", 0.5)
        fatigue_proxy = self.features.get("fatigue_proxy", 0.5)
        has_enough_data = self.features.get("has_enough_data", 0.0)
        
        task_has_data = self.features.get(f"{t_type}_has_data", 0.0)
        task_focus = self.features.get(f"{t_type}_focus", global_focus_score)
        
        base_score = 0.5 # Default starting score
        reason_codes = []

        # 1. Determine Effective Focus
        # Fallback to global focus if insufficient task history
        if task_has_data > 0:
            effective_focus = (global_focus_score * 0.4) + (task_focus * 0.6)
        else:
            effective_focus = global_focus_score

        # 2. Focus Match (Time Length vs Focus Capability)
        if work_min >= 40:
            if effective_focus >= 0.7:
                base_score += 0.3
                reason_codes.append(f"HIGH_FOCUS_CAPACITY_{t_type.upper()}")
            else:
                base_score -= 0.2
        elif work_min <= 25:
            if effective_focus < 0.5:
                base_score += 0.2
                reason_codes.append(f"SHORT_SESSION_FOR_LOW_FOCUS_{t_type.upper()}")
                
        # 3. Time-Of-Day Personalization (Only if supported by data)
        if task_has_data > 0:
            is_morning = self.features.get("is_morning", 0.0)
            is_afternoon = self.features.get("is_afternoon", 0.0)
            
            task_morning_focus = self.features.get(f"{t_type}_morning_focus")
            task_afternoon_focus = self.features.get(f"{t_type}_afternoon_focus")
            
            if is_morning > 0 and task_morning_focus is not None:
                if task_morning_focus >= 0.7:
                    base_score += 0.15
                    reason_codes.append(f"HISTORICAL_MORNING_STRENGTH_{t_type.upper()}")
                elif task_morning_focus < 0.4:
                    base_score -= 0.15
                    reason_codes.append(f"HISTORICAL_MORNING_WEAKNESS_{t_type.upper()}")
            
            if is_afternoon > 0 and task_afternoon_focus is not None:
                if task_afternoon_focus >= 0.7:
                    base_score += 0.15
                    reason_codes.append(f"HISTORICAL_AFTERNOON_STRENGTH_{t_type.upper()}")
                elif task_afternoon_focus < 0.4:
                    base_score -= 0.15
                    reason_codes.append(f"HISTORICAL_AFTERNOON_WEAKNESS_{t_type.upper()}")

        # 4. Fatigue Fit
        if fatigue_proxy > 0.6 and work_min >= 40:
            base_score -= 0.3
            reason_codes.append("HIGH_FATIGUE_LONG_SESSION_PENALTY")
        elif fatigue_proxy > 0.6 and candidate.break_min >= 10:
            base_score += 0.2
            reason_codes.append("LONGER_BREAK_FOR_FATIGUE")
            
        # Ensure bounds
        candidate.base_score = max(0.0, min(1.0, base_score))
        
        # Confidence calculation
        if task_has_data > 0:
            candidate.confidence = 0.8
        else:
            candidate.confidence = 0.3
            reason_codes.append("LOW_CONFIDENCE_MISSING_DATA")
            
        candidate.reason_codes = reason_codes
        return candidate


class ContextReRanker:
    """
    Adjusts Base Score using real-time context (Burnout, Weather).
    """
    def __init__(self, burnout_risk: Dict[str, Any], context: Dict[str, Any], features: Dict[str, float]):
        self.burnout_risk = burnout_risk
        self.context = context
        self.features = features

    def re_rank(self, candidates: List[RecommendationCandidate]) -> List[RecommendationCandidate]:
        risk_level = self.burnout_risk.get("risk_level", "LOW")
        is_hot = self.features.get("is_hot", 0.0)
        
        for cand in candidates:
            score_adj = 0.0
            
            # Burnout Penalty
            if risk_level == "CRITICAL" and cand.work_min >= 40:
                score_adj -= 0.4
                cand.reason_codes.append("CRITICAL_BURNOUT_RISK")
            elif risk_level == "CRITICAL" and cand.work_min <= 25:
                score_adj += 0.2
                cand.reason_codes.append("SHORT_SESSION_FOR_RECOVERY")
                
            # Weather Penalty
            if is_hot > 0.5 and cand.work_min > 30:
                score_adj -= 0.1
                cand.reason_codes.append("HOT_WEATHER_FATIGUE")
                
            cand.final_score = max(0.0, min(1.0, cand.base_score + score_adj))
            
        # Sort descending
        candidates.sort(key=lambda x: x.final_score, reverse=True)
        return candidates
