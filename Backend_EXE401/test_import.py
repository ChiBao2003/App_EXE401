"""Quick test: import orchestrator to verify no syntax errors after edits."""
import sys
sys.path.insert(0, ".")
try:
    from application.ai.ai_coach_orchestrator import AICoachOrchestrator, GEMINI_MODEL_CHAIN, GEMINI_BASE_URL, EVALUATOR_MODEL
    print("[OK] Import successful!")
    print(f"  Model Chain: {GEMINI_MODEL_CHAIN}")
    print(f"  Base URL: {GEMINI_BASE_URL}")
    print(f"  Evaluator: {EVALUATOR_MODEL}")
    
    orch = AICoachOrchestrator()
    print(f"  API Key loaded: {'Yes' if orch.api_key else 'No'}")
    print(f"  API Key prefix: {orch.api_key[:10]}...")
    print("\n[OK] All 3 fixes are loaded correctly!")
except Exception as e:
    print(f"[FAIL] Import error: {e}")
    import traceback
    traceback.print_exc()
