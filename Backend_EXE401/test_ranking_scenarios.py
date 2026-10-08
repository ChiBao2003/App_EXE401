import asyncio
import json
import sys
from application.ai.feature_engine import FeatureEngine
from application.ai.ranking_engine import CandidateGenerator, RankingEngine, ContextReRanker

sys.stdout.reconfigure(encoding='utf-8')

def run_test_scenario(name, digital_twin, context, current_hour):
    print(f"\\n--- SCENARIO: {name} ---")
    
    # 1. Feature Extraction
    features = FeatureEngine.extract_features(digital_twin, context, current_hour)
    print(f"Features Generated: {json.dumps(features, indent=2)}")
    
    # 2. Candidate Generation
    candidates = CandidateGenerator.generate_pomodoro_candidates()
    
    # 3. Base Ranking
    ranker = RankingEngine(features)
    scored = [ranker.score_pomodoro(c) for c in candidates]
    
    # 4. Context Re-ranking
    burnout_risk = digital_twin.get("burnout", {"risk_level": "LOW"})
    re_ranker = ContextReRanker(burnout_risk, context, features)
    final_candidates = re_ranker.re_rank(scored)
    
    print("\\nAll Ranked Candidates:")
    for c in final_candidates:
        print(f"  {c.work_min}/{c.break_min} | Base: {c.base_score:.2f} | Final: {c.final_score:.2f} | Conf: {c.confidence:.1f} | Reasons: {c.reason_codes}")
        
    print(f"\\n🏆 TOP CANDIDATE: {final_candidates[0].work_min}/{final_candidates[0].break_min} (Score: {final_candidates[0].final_score:.2f})")

def main():
    # A. Normal focus / low stress
    run_test_scenario(
        "A. Normal Focus / Low Stress",
        digital_twin={"focus_score": 80, "stress_level": 30, "break_score": 90, "total_sessions": 10},
        context={"temperature": 25, "weather": "clear"},
        current_hour=10
    )
    
    # B. High stress
    run_test_scenario(
        "B. High Stress",
        digital_twin={"focus_score": 60, "stress_level": 90, "break_score": 30, "total_sessions": 20},
        context={"temperature": 25, "weather": "clear"},
        current_hour=15
    )

    # C. CRITICAL burnout
    run_test_scenario(
        "C. CRITICAL Burnout",
        digital_twin={"focus_score": 40, "stress_level": 100, "break_score": 10, "total_sessions": 50, "burnout": {"risk_level": "CRITICAL"}},
        context={"temperature": 25, "weather": "clear"},
        current_hour=16
    )
    
    # D. Hot weather
    run_test_scenario(
        "D. Hot Weather",
        digital_twin={"focus_score": 75, "stress_level": 50, "break_score": 80, "total_sessions": 10},
        context={"temperature": 36, "weather": "sunny"},
        current_hour=14
    )

    # E. Missing weather/context data
    run_test_scenario(
        "E. Missing Context Data",
        digital_twin={"focus_score": 85, "stress_level": 20, "break_score": 90, "total_sessions": 15},
        context={},
        current_hour=9
    )

    # F. Insufficient historical data / cold-start user
    run_test_scenario(
        "F. Cold-start User",
        digital_twin={"total_sessions": 2}, # Default 50s for the rest
        context={"temperature": 24, "weather": "clear"},
        current_hour=11
    )

if __name__ == "__main__":
    main()
