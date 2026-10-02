from typing import List, Dict, Any, Optional

class MLDatasetBuilder:
    def __init__(self):
        pass
        
    def build_pointwise_dataset(self, logs: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """
        Transforms raw ai_recommendation_logs into ML-ready Pointwise rows.
        Only extracts the SELECTED/OBSERVED candidate for each row.
        """
        dataset = []
        for log in logs:
            if not self._is_resolved(log):
                continue
                
            row = self._extract_base_info(log)
            row.update(self._extract_safe_features(log))
            
            # Candidate Matching for the selected configuration
            actual_work = log.get("actual_work_min")
            actual_break = log.get("actual_break_min")
            actual_type = log.get("actual_task_type")
            
            # Find which candidate the user actually adopted (if any)
            matched_rank = self._find_candidate_rank(
                log.get("top_k_candidates", []), 
                actual_work, 
                actual_break, 
                actual_type
            )
            
            row["observed_candidate_rank"] = matched_rank
            row["actual_work_min"] = actual_work
            row["actual_break_min"] = actual_break
            row["actual_task_type"] = actual_type
            
            # Labels
            row["label_accepted"] = log.get("accepted")
            row["label_completed"] = log.get("completed")
            row["label_outcome"] = log.get("outcome")
            
            dataset.append(row)
            
        return dataset
        
    def build_candidate_expansion_dataset(self, logs: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """
        Transforms raw ai_recommendation_logs into ML-ready Candidate-Level Pointwise rows (MODE B).
        Expands one recommendation into multiple rows (one for each candidate in top_k_candidates).
        Unselected real candidates are left with label = None (UNOBSERVED), NOT negative.
        """
        dataset = []
        for log in logs:
            if not self._is_resolved(log):
                continue
                
            base_info = self._extract_base_info(log)
            context_features = self._extract_safe_features(log)
            
            actual_work = log.get("actual_work_min")
            actual_break = log.get("actual_break_min")
            actual_type = log.get("actual_task_type")
            data_source = log.get("data_source", "real")
            
            matched_rank = self._find_candidate_rank(
                log.get("top_k_candidates", []), 
                actual_work, 
                actual_break, 
                actual_type
            )
            
            for i, cand in enumerate(log.get("top_k_candidates", [])):
                row = base_info.copy()
                row.update(context_features)
                
                # Candidate Features
                row["candidate_work_min"] = cand.get("work_min")
                row["candidate_break_min"] = cand.get("break_min")
                row["candidate_task_type"] = cand.get("candidate_type")
                row["candidate_rank"] = i + 1
                row["data_source"] = data_source
                
                # Observed Labels Assignment
                if matched_rank == (i + 1):
                    # This candidate was observed
                    row["label_accepted"] = log.get("accepted")
                    row["label_completed"] = log.get("completed")
                    row["label_outcome"] = log.get("outcome")
                    row["is_observed"] = True
                else:
                    # This candidate was UNOBSERVED. Do NOT fabricate negative labels.
                    row["label_accepted"] = None
                    row["label_completed"] = None
                    row["label_outcome"] = None
                    row["is_observed"] = False
                    
                dataset.append(row)
                
        return dataset
        
    def _is_resolved(self, log: Dict[str, Any]) -> bool:
        """
        A log is unresolved if it has no explicit user feedback/outcome.
        We do NOT silently convert missing labels to negative labels.
        """
        return "accepted" in log or "outcome" in log
        
    def _extract_base_info(self, log: Dict[str, Any]) -> Dict[str, Any]:
        return {
            "recommendation_id": log.get("recommendation_id"),
            "user_id": log.get("user_id"),
            "timestamp": log.get("timestamp")
        }
        
    def _extract_safe_features(self, log: Dict[str, Any]) -> Dict[str, Any]:
        """
        Extracts only pre-recommendation features. Prevents leakage.
        """
        features_used = log.get("features_used", {})
        
        # Explicitly whitelist pre-recommendation features
        # Do NOT include concentration_score or completion_rate from the current session
        safe_features = {}
        for k, v in features_used.items():
            if k not in ["concentration_score", "completion_rate", "accepted", "completed", "outcome"]:
                safe_features[k] = v
                
        return safe_features
        
    def _find_candidate_rank(self, top_k: List[Dict[str, Any]], work: int, break_min: int, task_type: str) -> Optional[int]:
        """
        Identifies which candidate rank matches the user's actual configuration.
        """
        if not work or not break_min:
            return None
            
        for i, cand in enumerate(top_k):
            if cand.get("work_min") == work and cand.get("break_min") == break_min:
                # If candidate_type exists, check it. Otherwise, match by time.
                if cand.get("candidate_type") and task_type:
                    if cand.get("candidate_type") == task_type:
                        return i + 1
                else:
                    return i + 1
        return None
