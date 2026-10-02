# Ð?C T? GIAO TH?C & API (PROTOCOL SPECIFICATION)
**Phiên b?n:** 1.0

## 1. Giao th?c Bluetooth SPP (Ph?n c?ng -> App)
D? li?u du?c ESP32 g?i di du?i d?ng chu?i van b?n thu?n túy (Plain Text JSON) thông qua Bluetooth Serial (SPP). T?c d? truy?n (Baudrate không áp d?ng ch?t ch? qua SPP nhung m?c d?nh s? d?ng lu?ng buffer n?i ti?p).

**Payload m?u t? ESP32:**
```json
{
  "mode": "pomodoro",
  "work_min": 25,
  "break_min": 5,
  "pauses": 2,
  "completed": true,
  "session": 1
}
```
*Ghi chú:* ESP32 k?t thúc m?i chu?i JSON b?ng ký t? `\n` (newline). ?ng d?ng Flutter s? can c? vào ký t? này d? c?t chu?i (buffer splitting).

## 2. REST API (App -> Backend)
**Endpoint:** `POST /api/v1/pomodoro/sync`
**Mô t?:** Nh?n d? li?u phiên làm vi?c, luu tr? và tr? v? k?t qu? phân tích AI.

**Request Payload (t? Flutter):**
```json
{
  "user_id": "user_local_001",
  "hardware_data": {
    "work_min": 25,
    "break_min": 5,
    "pauses": 2,
    "completed": true,
    "session_count": 1
  },
  "phone_data": {
    "unlock_count": 4,
    "timestamp": "2026-09-11T14:30:00.000Z"
  }
}
```

**Response Payload (t? Backend):**
```json
{
  "status": "ok",
  "session_id": "64fe...abcd",
  "feedback": "?? Phiên 25 phút có 2 l?n pause và 4 l?n m? khóa di?n tho?i. Hãy th? d?t di?n tho?i xa t?m tay nhé!",
  "summary": {
    "work_min": 25,
    "completed": true,
    "total_distractions": 6
  }
}
```
