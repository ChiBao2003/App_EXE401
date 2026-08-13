from fastapi import APIRouter, Request
from models.market_template import MarketTemplate
from typing import List
from datetime import datetime

router = APIRouter()

@router.get("/", summary="Lấy danh sách các mẫu thiết kế trên Chợ")
async def get_market_templates(request: Request):
    """
    Trả về toàn bộ các mẫu thiết kế đang có trên Chợ hiệu ứng, lấy trực tiếp từ MongoDB.
    """
    db = request.app.database
    templates = []
    
    # Lấy toàn bộ dữ liệu từ bảng market_templates trong MongoDB
    cursor = db["market_templates"].find()
    async for document in cursor:
        # MongoDB sử dụng ObjectId cho trường _id, ta cần chuyển thành chuỗi string để gửi qua JSON
        document["_id"] = str(document["_id"])
        templates.append(document)
        
    return templates

@router.post("/", summary="Tải lên một mẫu thiết kế mới")
async def upload_market_template(request: Request, template: MarketTemplate):
    """
    Cho phép người dùng upload một bản thiết kế mới lên Chợ, lưu thẳng vào MongoDB.
    """
    db = request.app.database
    
    # Chuyển đổi dữ liệu Python sang dạng Dictionary chuẩn JSON
    template_dict = template.dict()
    
    # Lưu vào database MongoDB
    result = await db["market_templates"].insert_one(template_dict)
    
    return {
        "message": "Upload template thành công!", 
        "inserted_id": str(result.inserted_id)
    }
