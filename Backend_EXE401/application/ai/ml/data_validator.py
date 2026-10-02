from typing import List, Dict, Any

class MLDataValidator:
    def __init__(self):
        pass
        
    def validate_dataset(self, logs: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Validates the raw ai_recommendation_logs to ensure they are safe for ML training.
        """
        report = {
            "TOTAL_ROWS": len(logs),
            "LABELED_ROWS": 0,
            "UNRESOLVED_ROWS": 0,
            "ROWS_WITH_LEAKAGE": 0,
            "ROWS_WITH_INVALID_FEATURES": 0,
            "ROWS_WITH_DUPLICATE_IDS": 0,
            "ROWS_MISSING_ID": 0,
            "ROWS_MALFORMED_CANDIDATES": 0,
        }
        
        seen_ids = set()
        
        for log in logs:
            # Check ID
            rec_id = log.get("recommendation_id")
            if not rec_id:
                report["ROWS_MISSING_ID"] += 1
            else:
                if rec_id in seen_ids:
                    report["ROWS_WITH_DUPLICATE_IDS"] += 1
                seen_ids.add(rec_id)
                
            # Check Unresolved
            if "accepted" not in log and "outcome" not in log:
                report["UNRESOLVED_ROWS"] += 1
            else:
                report["LABELED_ROWS"] += 1
                
            # Check Features and Leakage
            features = log.get("features_used", {})
            if not isinstance(features, dict) or len(features) == 0:
                report["ROWS_WITH_INVALID_FEATURES"] += 1
                
            # Leakage check: post-outcome labels inside features_used
            leakage_keys = ["concentration_score", "completion_rate", "accepted", "completed", "outcome"]
            if any(k in features for k in leakage_keys):
                report["ROWS_WITH_LEAKAGE"] += 1
                
            # Check Candidates
            top_k = log.get("top_k_candidates", [])
            if not isinstance(top_k, list) or len(top_k) == 0:
                report["ROWS_MALFORMED_CANDIDATES"] += 1
                
        return report
