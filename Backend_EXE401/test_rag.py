"""
test_rag.py
Run this to test the Vector RAG implementation.
"""
import asyncio
import os
from application.ai.rag_service import RAGService

async def main():
    print("Khởi tạo RAG Service...")
    # Lấy GEMINI_API_KEY từ file .env nếu có, nếu không thì gắn trực tiếp vào đây để test
    from dotenv import load_dotenv
    load_dotenv()
    
    rag_svc = RAGService(persist_directory="storage/chroma")
    
    user_id = "ead8d66d-431c-4125-96c4-18b949103b83" # ID của bạn

    print("1. Nhúng (Embed) một vài kiến thức cũ vào ChromaDB...")
    knowledge = (
        "Ngày 15/09: Tôi đã hoàn thành xuất sắc 3 phiên làm việc tập trung cao độ, "
        "tổng cộng 75 phút không hề lướt điện thoại. Điểm focus là 95/100."
    )
    
    knowledge2 = (
        "Quy định cá nhân: Nếu nhiệt độ phòng > 33 độ C, tôi chỉ làm việc 20 phút và nghỉ 10 phút. "
        "Mục tiêu là hạn chế mệt mỏi."
    )
    
    await rag_svc.index_document(user_id=user_id, document_text=knowledge, source="pomodoro_log_summary")
    await rag_svc.index_document(user_id=user_id, document_text=knowledge2, source="user_preferences")
    
    print("-> Index xong!")
    
    print("\n2. Thử truy vấn ngữ nghĩa (Vector Search)...")
    query1 = "Hôm bữa ngày 15 tôi tập trung thế nào?"
    print(f"Câu hỏi: {query1}")
    res1 = await rag_svc.search_context(user_id, query1, top_k=1)
    print(f"Kết quả RAG tìm được:\n{res1}\n")
    
    query2 = "Trời nóng quá thì tôi nên làm việc bao nhiêu phút?"
    print(f"Câu hỏi: {query2}")
    res2 = await rag_svc.search_context(user_id, query2, top_k=1)
    print(f"Kết quả RAG tìm được:\n{res2}\n")

if __name__ == "__main__":
    asyncio.run(main())
