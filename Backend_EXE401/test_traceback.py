import asyncio
import sys
import os
import traceback
from motor.motor_asyncio import AsyncIOMotorClient

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from application.ai.ai_coach_orchestrator import AICoachOrchestrator

async def test_traceback():
    client = AsyncIOMotorClient("mongodb://localhost:27017")
    db = client["Pomodoro_App"]
    
    # We will test the exact block of code from ai_router.py that injects phone_usage
    user_id = "60c72b2f9b1d8b1f8c123456" # fake user
    
    from datetime import datetime
    today_str = datetime.utcnow().strftime("%Y-%m-%d")
    
    # Just to get the exact exception, let's run the DB query
    try:
        usage_summary = await db["daily_summaries"].find_one({"user_id": user_id, "date": today_str})
        
        digital_twin = {}
        if usage_summary:
            total_mins = usage_summary.get("total_screen_time_ms", 0) // 60000
            total_h, total_m = divmod(total_mins, 60)
            prod_mins = usage_summary.get("productive_apps_time_ms", 0) // 60000
            dist_mins = usage_summary.get("distraction_apps_time_ms", 0) // 60000
            top_dist = usage_summary.get("top_distraction_apps", [])
            top_dist_text = ", ".join(
                f"{app.get('app_name', '?')}({app.get('time_ms', 0) // 60000}m)"
                for app in top_dist[:3]
            ) or "Không có"

            digital_twin["phone_usage"] = {
                "screen_time": f"{total_h}h {total_m}m",
                "unlocks": usage_summary.get("total_unlocks", 0),
                "focus_score": usage_summary.get("focus_score", 0),
                "productive_time_min": prod_mins,
                "distraction_time_min": dist_mins,
                "top_distraction_apps": top_dist_text,
                "pomo_distractions": usage_summary.get("total_distractions_during_pomo", 0),
                "pomo_distraction_rate": usage_summary.get("pomo_distraction_rate", 0),
            }
            
        print("Digital twin phone_usage built successfully:", digital_twin.get("phone_usage"))
        
        orchestrator = AICoachOrchestrator()
        res = await orchestrator.chat(
            user_id=user_id,
            user_prompt="Hello",
            digital_twin=digital_twin,
            context={"time": "morning"},
            watch_status={"connected": True},
            chat_history=[]
        )
        print("Orchestrator responded!")
        
    except Exception as e:
        print("Exception caught!")
        traceback.print_exc()

if __name__ == "__main__":
    asyncio.run(test_traceback())
