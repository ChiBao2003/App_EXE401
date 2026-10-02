import uuid
import sys
import os
from datetime import datetime

# Add parent to path to import dataset_builder and data_validator
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../../..')))
from application.ai.ml.dataset_builder import MLDatasetBuilder
from application.ai.ml.data_validator import MLDataValidator

def run_tests():
    builder = MLDatasetBuilder()
    validator = MLDataValidator()
    
    top_k = [
        {"work_min": 20, "break_min": 5, "candidate_type": "coding"},
        {"work_min": 25, "break_min": 5, "candidate_type": "coding"},
        {"work_min": 30, "break_min": 5, "candidate_type": "coding"},
        {"work_min": 40, "break_min": 10, "candidate_type": "coding"},
        {"work_min": 50, "break_min": 10, "candidate_type": "coding"},
    ]
    
    # Test A: Observed candidate #1
    log_a = {
        "recommendation_id": "R_A", "user_id": "U1", "timestamp": "2026-01-01T10:00:00Z",
        "top_k_candidates": top_k, "actual_work_min": 20, "actual_break_min": 5, "actual_task_type": "coding",
        "accepted": True, "completed": True, "outcome": 85.0
    }
    out_a = builder.build_candidate_expansion_dataset([log_a])
    print(f"Test A (#1 observed): Rank 1 is_observed={out_a[0]['is_observed']}, Labels: {out_a[0]['label_accepted']} / Rank 2 is_observed={out_a[1]['is_observed']}, Labels: {out_a[1]['label_accepted']}")

    # Test B: Observed candidate #3
    log_b = {
        "recommendation_id": "R_B", "user_id": "U1", "timestamp": "2026-01-01T10:00:00Z",
        "top_k_candidates": top_k, "actual_work_min": 30, "actual_break_min": 5, "actual_task_type": "coding",
        "accepted": False, "completed": True, "outcome": 70.0
    }
    out_b = builder.build_candidate_expansion_dataset([log_b])
    print(f"Test B (#3 observed): Rank 3 is_observed={out_b[2]['is_observed']}, Labels: {out_b[2]['label_accepted']} / Rank 1 is_observed={out_b[0]['is_observed']}, Labels: {out_b[0]['label_accepted']}")

    # Test C: Actual config not in Top-K
    log_c = {
        "recommendation_id": "R_C", "user_id": "U1", "timestamp": "2026-01-01T10:00:00Z",
        "top_k_candidates": top_k, "actual_work_min": 45, "actual_break_min": 15, "actual_task_type": "coding",
        "accepted": False, "completed": True, "outcome": 60.0
    }
    out_c = builder.build_candidate_expansion_dataset([log_c])
    any_observed = any(r['is_observed'] for r in out_c)
    print(f"Test C (Not in Top-K): Any observed? {any_observed}")
    
    # Test D: Missing accepted but outcome exists
    log_d = {
        "recommendation_id": "R_D", "user_id": "U1", "timestamp": "2026-01-01T10:00:00Z",
        "top_k_candidates": top_k, "actual_work_min": 25, "actual_break_min": 5, "actual_task_type": "coding",
        "completed": True, "outcome": 90.0
    }
    out_d = builder.build_candidate_expansion_dataset([log_d])
    rank2_d = out_d[1]
    print(f"Test D (Missing accepted): label_accepted={rank2_d.get('label_accepted')}, label_outcome={rank2_d.get('label_outcome')}")
    
    # Test E: Unobserved candidate
    print(f"Test E (Unobserved cand): Rank 4 in Test A label_accepted={out_a[3].get('label_accepted')}, label_outcome={out_a[3].get('label_outcome')}")
    
    # Test F: Leakage injection
    log_f = {
        "recommendation_id": "R_F", "user_id": "U1", "timestamp": "2026-01-01T10:00:00Z",
        "top_k_candidates": top_k, "features_used": {"concentration_score": 99},
        "accepted": True, "outcome": 99.0
    }
    rep_f = validator.validate_dataset([log_f])
    print(f"Test F (Leakage): ROWS_WITH_LEAKAGE = {rep_f['ROWS_WITH_LEAKAGE']}")
    
    # Test G: Duplicate recommendation_id
    log_g1 = {"recommendation_id": "R_G", "user_id": "U1", "top_k_candidates": top_k, "accepted": True, "outcome": 90.0}
    log_g2 = {"recommendation_id": "R_G", "user_id": "U1", "top_k_candidates": top_k, "accepted": False, "outcome": 50.0}
    rep_g = validator.validate_dataset([log_g1, log_g2])
    print(f"Test G (Duplicate ID): ROWS_WITH_DUPLICATE_IDS = {rep_g['ROWS_WITH_DUPLICATE_IDS']}")

if __name__ == "__main__":
    run_tests()
