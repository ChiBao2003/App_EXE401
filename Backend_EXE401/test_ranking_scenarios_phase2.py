import asyncio
import json
from application.ai.feature_engine import FeatureEngine
from application.ai.ranking_engine import CandidateGenerator, RankingEngine, ContextReRanker

def run_test_scenario(name, digital_twin, context, current_hour):
    print(f"\n--- SCENARIO: {name} ---")
    
    # 1. Feature Extraction
    features = FeatureEngine.extract_features(digital_twin, context, current_hour)
    
    # 2. Candidate Generation
    candidates = CandidateGenerator.generate_pomodoro_candidates()
    
    # 3. Base Ranking
    ranker = RankingEngine(features)
    scored = [ranker.score_pomodoro(c) for c in candidates]
    
    # 4. Context Re-ranking
    burnout_risk = digital_twin.get("burnout", {"risk_level": "LOW"})
    re_ranker = ContextReRanker(burnout_risk, context, features)
    final_candidates = re_ranker.re_rank(scored)
    
    print("\nTop 5 Candidates:")
    for c in final_candidates[:5]:
        print(f"  {c.candidate_type} {c.work_min}/{c.break_min} | Base: {c.base_score:.2f} | Final: {c.final_score:.2f} | Conf: {c.confidence:.1f} | Reasons: {c.reason_codes}")
        
    print(f"\n🏆 TOP CANDIDATE: {final_candidates[0].candidate_type} {final_candidates[0].work_min}/{final_candidates[0].break_min} (Score: {final_candidates[0].final_score:.2f})")

def main():
    # A. User with strong coding history
    run_test_scenario(
        "A. Strong coding history",
        digital_twin={
            "focus_score": 50, "stress_level": 30, "break_score": 80, "total_sessions": 20,
            "task_performance": {
                "coding": {"session_count": 10, "avg_focus": 90.0},
                "reading": {"session_count": 10, "avg_focus": 30.0}
            }
        },
        context={"temperature": 25, "weather": "clear"},
        current_hour=10
    )
    
    # B. Strong reading history
    run_test_scenario(
        "B. Strong reading history",
        digital_twin={
            "focus_score": 50, "stress_level": 30, "break_score": 80, "total_sessions": 20,
            "task_performance": {
                "coding": {"session_count": 10, "avg_focus": 20.0},
                "reading": {"session_count": 10, "avg_focus": 95.0}
            }
        },
        context={"temperature": 25, "weather": "clear"},
        current_hour=10
    )

    # C. Task-type performance varies by time of day
    run_test_scenario(
        "C. Coding bad in morning, good in afternoon",
        digital_twin={
            "focus_score": 60, "stress_level": 40, "break_score": 70, "total_sessions": 30,
            "task_performance": {
                "coding": {"session_count": 20, "avg_focus": 60.0, "morning_focus": 20.0, "afternoon_focus": 95.0}
            }
        },
        context={"temperature": 25, "weather": "clear"},
        current_hour=14 # Afternoon
    )
    
    # D. High stress
    run_test_scenario(
        "D. High Stress",
        digital_twin={
            "focus_score": 60, "stress_level": 90, "break_score": 20, "total_sessions": 30,
            "task_performance": {
                "coding": {"session_count": 20, "avg_focus": 80.0},
                "reading": {"session_count": 10, "avg_focus": 80.0}
            }
        },
        context={"temperature": 25, "weather": "clear"},
        current_hour=10
    )

    # E. Critical burnout
    run_test_scenario(
        "E. Critical burnout",
        digital_twin={
            "focus_score": 50, "stress_level": 95, "break_score": 10, "total_sessions": 40,
            "burnout": {"risk_level": "CRITICAL"},
            "task_performance": {
                "coding": {"session_count": 20, "avg_focus": 90.0}
            }
        },
        context={"temperature": 25, "weather": "clear"},
        current_hour=15
    )

    # F. Insufficient task-type history
    run_test_scenario(
        "F. Insufficient task-type history (only 1 coding session)",
        digital_twin={
            "focus_score": 80, "stress_level": 20, "break_score": 90, "total_sessions": 50,
            "task_performance": {
                "coding": {"session_count": 1, "avg_focus": 100.0} # Should be ignored
            }
        },
        context={"temperature": 25, "weather": "clear"},
        current_hour=11
    )

    # G. No task-type data
    run_test_scenario(
        "G. No task-type data",
        digital_twin={
            "focus_score": 80, "stress_level": 20, "break_score": 90, "total_sessions": 5,
        },
        context={"temperature": 25, "weather": "clear"},
        current_hour=11
    )

if __name__ == "__main__":
    main()
