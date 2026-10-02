import asyncio
from motor.motor_asyncio import AsyncIOMotorClient

async def check_real_data():
    client = AsyncIOMotorClient("mongodb://localhost:27017")
    db = client["Pomodoro_App"]
    
    summaries = await db["daily_summaries"].find().to_list(length=5)
    print("=== REAL DATA IN MONGODB ===")
    if not summaries:
        print("No data in daily_summaries.")
    else:
        for s in summaries:
            print(f"- User ID: {s.get('user_id')}")
            print(f"  Date: {s.get('date')}")
            print(f"  Screen time: {s.get('total_screen_time_ms', 0) // 60000} mins")
            print(f"  Unlocks: {s.get('total_unlocks')}")
            print(f"  Focus score: {s.get('focus_score')}")
            top = s.get('top_distraction_apps', [])
            if top:
                print(f"  Top distraction: {top[0].get('app_name')} ({top[0].get('time_ms', 0) // 60000} mins)")
            print("-" * 40)

if __name__ == "__main__":
    asyncio.run(check_real_data())
