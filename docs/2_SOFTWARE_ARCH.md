# TÀI LI?U KI?N TRÚC PH?N M?M (SOFTWARE ARCHITECTURE)
**Phiên b?n:** 1.0
**Mô dun:** Flutter App (Mobile) & FastAPI (Backend)

## 1. ?ng d?ng Di d?ng (Frontend - Flutter)
- **Framework:** Flutter SDK (Dart)
- **Ki?n trúc:** Feature-based Clean Architecture.
- **State Management:** Provider (s? d?ng `ChangeNotifier`).
- **Thành ph?n c?t lõi (Core Services):**
  - `SppService`: Qu?n lý k?t n?i Bluetooth Classic SPP, lu?ng nh?n d? li?u byte, parse JSON và trigger vi?c g?i d? li?u lên Backend.
  - `BleService`: D? phòng cho vi?c cài d?t và d?ng b? OTA (Over-The-Air) qua Bluetooth Low Energy tuong lai.

## 2. Backend Server (FastAPI)
- **Framework:** FastAPI (Python 3.10+)
- **Ki?n trúc:** RESTful API v?i Routing Controller Pattern.
- **Database:** MongoDB (S? d?ng thu vi?n Async `Motor`).
- **Validation:** Pydantic Models (Ki?m soát ch?t ch? schema d? li?u t? di?n tho?i g?i lên).
- **AI Feedback Engine:**
  - *Hi?n t?i:* Rule-based Engine phân tích tuong quan gi?a s? l?n b?m pause (t? ph?n c?ng) và s? l?n m? khóa (t? di?n tho?i).
  - *Ð?nh hu?ng:* Có th? scale up tích h?p LangChain ho?c g?i tr?c ti?p OpenAI API/Gemini API d? sinh l?i khuyên d?a trên l?ch s? d? li?u l?n.
