from fastapi import APIRouter, Request

router = APIRouter()

@router.get("/latest")
async def get_latest_firmware(request: Request):
    firmwares_cursor = request.app.database["firmwares"].find().sort("version", -1).limit(1)
    firmwares = await firmwares_cursor.to_list(length=1)
    if firmwares:
        firmwares[0]["_id"] = str(firmwares[0]["_id"])
        return firmwares[0]
    return {"message": "No firmware available"}
