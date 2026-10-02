"""
application/ai/feature_engine.py
Centralized Feature Engineering for AI recommendations.
Extracts and normalizes features from User Digital Twin, Context, and other sources.
All features should ideally be normalized to [0.0, 1.0] for easier ranking.
"""
from typing import Dict, Any
from datetime import datetime

class FeatureEngine:
    @staticmethod
    def extract_features(
        digital_twin: Dict[str, Any], 
        context: Dict[str, Any], 
        current_hour: int
    ) -> Dict[str, float]:
        """
        Extracts a standard feature vector for ranking models.
        """
        # 1. Profile Features (Normalized 0.0 - 1.0)
        focus_score = digital_twin.get("focus_score", 50.0) / 100.0
        stress_level = digital_twin.get("stress_level", 50.0) / 100.0
        break_score = digital_twin.get("break_score", 50.0) / 100.0
        efficiency = digital_twin.get("efficiency", 50.0) / 100.0
        
        total_sessions = digital_twin.get("total_sessions", 0)
        has_enough_data = 1.0 if total_sessions >= 5 else 0.0

        # 2. Context Features
        # Determine time of day suitability (e.g. morning vs evening)
        is_morning = 1.0 if 5 <= current_hour < 12 else 0.0
        is_afternoon = 1.0 if 12 <= current_hour < 18 else 0.0
        is_evening = 1.0 if 18 <= current_hour <= 23 else 0.0
        
        # Weather context mapping (if available)
        weather_condition = context.get("weather", "").lower()
        temp = context.get("temperature", 25)
        is_hot = 1.0 if temp >= 33 else 0.0
        is_rainy = 1.0 if "rain" in weather_condition else 0.0

        # 3. Task Performance Features
        task_perf = digital_twin.get("task_performance", {})
        task_features = {}
        for t_type, stats in task_perf.items():
            session_count = stats.get("session_count", 0)
            avg_focus = stats.get("avg_focus", 50.0) / 100.0
            
            # Require at least 3 sessions for personalized task stats
            has_enough = 1.0 if session_count >= 3 else 0.0
            
            morning_focus = stats.get("morning_focus")
            afternoon_focus = stats.get("afternoon_focus")
            
            task_features[f"{t_type}_has_data"] = has_enough
            task_features[f"{t_type}_focus"] = avg_focus
            
            if morning_focus is not None:
                task_features[f"{t_type}_morning_focus"] = morning_focus / 100.0
            if afternoon_focus is not None:
                task_features[f"{t_type}_afternoon_focus"] = afternoon_focus / 100.0

        # Derived Features
        # Fatigue Proxy: High stress + Low break score
        fatigue_proxy = max(0.0, min(1.0, stress_level + (1.0 - break_score)))
        
        result = {
            "focus_score": focus_score,
            "stress_level": stress_level,
            "break_score": break_score,
            "efficiency": efficiency,
            "has_enough_data": has_enough_data,
            "is_morning": is_morning,
            "is_afternoon": is_afternoon,
            "is_evening": is_evening,
            "is_hot": is_hot,
            "is_rainy": is_rainy,
            "fatigue_proxy": fatigue_proxy
        }
        
        # Merge task features
        result.update(task_features)
        
        return result
