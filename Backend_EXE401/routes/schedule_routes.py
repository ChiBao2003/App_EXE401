from fastapi import APIRouter, Request

router = APIRouter()

@router.get("/")
async def get_schedules(request: Request):
    schedules_cursor = request.app.database["schedules"].find()
    schedules = await schedules_cursor.to_list(length=100)
    for item in schedules:
        item["_id"] = str(item["_id"])
    return schedules

@router.post("/")
async def create_schedule(request: Request, schedule: dict):
    new_schedule = await request.app.database["schedules"].insert_one(schedule)
    return {"status": "success", "id": str(new_schedule.inserted_id)}
