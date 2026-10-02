import random
import uuid
import sys
import os
from datetime import datetime, timedelta

# Add parent to path to import dataset_builder and data_validator
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../../..')))
from application.ai.ml.dataset_builder import MLDatasetBuilder
from application.ai.ml.data_validator import MLDataValidator

class UserBehaviorSimulator:
    def __init__(self):
        self.profiles = {
            "User_A": {"preferred_work": 25, "fatigue_sensitive": False},
            "User_B": {"preferred_work": 40, "fatigue_sensitive": False},
            "User_C": {"preferred_work": 25, "fatigue_sensitive": True},
        }
        self.candidate_pool = [
            {"work_min": 20, "break_min": 5, "candidate_type": "coding"},
            {"work_min": 25, "break_min": 5, "candidate_type": "coding"},
            {"work_min": 30, "break_min": 5, "candidate_type": "coding"},
            {"work_min": 40, "break_min": 10, "candidate_type": "coding"},
            {"work_min": 50, "break_min": 10, "candidate_type": "coding"},
        ]
        
    def run_simulation(self):
        print("--- PHASE 4.1 SYNTHETIC PIPELINE TEST ---")
        logs = self._generate_synthetic_logs(1000)
        
        # Inject deliberate leakage test case
        corrupted_log = self._generate_single_log(datetime.utcnow())
        corrupted_log["features_used"]["concentration_score"] = 99.0
        
        print("\n[TEST] Validator Leakage Detection")
        validator = MLDataValidator()
        corrupted_report = validator.validate_dataset([corrupted_log])
        if corrupted_report["ROWS_WITH_LEAKAGE"] == 1:
            print("  PASS: Validator successfully detected deliberate leakage.")
        else:
            print("  FAIL: Validator failed to detect leakage.")
            
        print("\n[TEST] Normal Dataset Validation")
        report = validator.validate_dataset(logs)
        for k, v in report.items():
            print(f"  {k}: {v}")
            
        print("\n[TEST] Dataset Builder Processing")
        builder = MLDatasetBuilder()
        dataset = builder.build_pointwise_dataset(logs)
        print(f"  Generated {len(dataset)} ML-ready rows from {len(logs)} raw logs.")
        
        if len(dataset) > 0:
            sample = dataset[0]
            print(f"  Sample row safe keys: {list(sample.keys())}")
            
            # Check Temporal Split
            timestamps = [d["timestamp"] for d in dataset]
            # Since dataset is chronologically ordered
            split_70 = int(len(dataset) * 0.7)
            split_85 = int(len(dataset) * 0.85)
            
            train_ts = timestamps[:split_70]
            val_ts = timestamps[split_70:split_85]
            test_ts = timestamps[split_85:]
            
            print("\n[TEST] Temporal Split")
            print(f"  Train: {len(train_ts)} rows. Max TS: {max(train_ts)}")
            if len(val_ts) > 0:
                print(f"  Validation: {len(val_ts)} rows. Min TS: {min(val_ts)}, Max TS: {max(val_ts)}")
            if len(test_ts) > 0:
                print(f"  Test: {len(test_ts)} rows. Min TS: {min(test_ts)}")
                
            if max(train_ts) <= min(val_ts) and max(val_ts) <= min(test_ts):
                print("  PASS: Strict chronological ordering verified without overlap.")
            else:
                print("  FAIL: Temporal overlap detected.")
                
        print("\n[TEST] Candidate Expansion Dataset Processing (MODE B)")
        expansion_dataset = builder.build_candidate_expansion_dataset(logs)
        print(f"  Generated {len(expansion_dataset)} candidate-level rows from {len(logs)} raw logs.")
        
        if len(expansion_dataset) > 0:
            observed_rows = [r for r in expansion_dataset if r["is_observed"]]
            unobserved_rows = [r for r in expansion_dataset if not r["is_observed"]]
            print(f"  Observed candidates (labels assigned): {len(observed_rows)}")
            print(f"  Unobserved candidates (labels=None): {len(unobserved_rows)}")
            
            # Verify no unobserved candidate got negative labels
            fake_labels = [r for r in unobserved_rows if r["label_accepted"] is not None]
            if len(fake_labels) == 0:
                print("  PASS: Unobserved candidates are strictly left unlabeled.")
            else:
                print("  FAIL: Fake labels generated for unobserved candidates.")
                
            sample_exp = expansion_dataset[0]
            print(f"  Sample candidate row keys: {list(sample_exp.keys())}")
            
        # Scenarios Tests (Check for specific injected anomalies if needed)
        
    def _generate_synthetic_logs(self, count: int) -> list:
        logs = []
        base_time = datetime.utcnow() - timedelta(days=90)
        
        for i in range(count):
            current_time = base_time + timedelta(minutes=i*120)
            log = self._generate_single_log(current_time)
            logs.append(log)
            
        # Add some unresolved rows
        for i in range(20):
            unresolved = self._generate_single_log(datetime.utcnow())
            if "accepted" in unresolved: del unresolved["accepted"]
            if "outcome" in unresolved: del unresolved["outcome"]
            if "completed" in unresolved: del unresolved["completed"]
            logs.append(unresolved)
            
        return logs

    def _generate_single_log(self, dt: datetime) -> dict:
        user_id = random.choice(list(self.profiles.keys()))
        profile = self.profiles[user_id]
        
        fatigue = random.random()
        focus = random.random()
        
        # Synthetic Top-K Candidates (Minimal simulation-only candidate set)
        top_k = self.candidate_pool[:]
        random.shuffle(top_k)
        top_candidate = top_k[0]
        
        # Latent preference: choose actual config
        actual_work = profile["preferred_work"]
        if profile["fatigue_sensitive"] and fatigue > 0.7:
            actual_work = 20
            
        # Add stochastic variation
        if random.random() < 0.2:
            # Randomly accept AI recommendation even if not preferred
            actual_work = top_candidate["work_min"]
            
        actual_break = 5 if actual_work <= 30 else 10
        actual_type = "coding"
        
        # Generate strict semantic labels
        accepted = (actual_work == top_candidate["work_min"] and 
                    actual_break == top_candidate["break_min"] and 
                    actual_type == top_candidate["candidate_type"])
                    
        completion_rate = random.uniform(80.0, 100.0) if random.random() > 0.1 else random.uniform(10.0, 50.0)
        completed = completion_rate >= 90.0
        
        outcome = random.uniform(40.0, 100.0)
        
        return {
            "data_source": "synthetic",
            "recommendation_id": str(uuid.uuid4()),
            "user_id": user_id,
            "timestamp": dt.isoformat(),
            "candidate": top_candidate,
            "top_k_candidates": top_k,
            "features_used": {
                "fatigue_proxy": fatigue,
                "focus_score": focus,
                "hour_of_day_norm": dt.hour / 24.0,
                "day_of_week_norm": dt.weekday() / 6.0,
            },
            "shown": True,
            "actual_work_min": actual_work,
            "actual_break_min": actual_break,
            "actual_task_type": actual_type,
            "accepted": accepted,
            "completed": completed,
            "outcome": outcome
        }

if __name__ == "__main__":
    sim = UserBehaviorSimulator()
    sim.run_simulation()
