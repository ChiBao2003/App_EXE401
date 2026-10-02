import requests
import json

url = "http://127.0.0.1:8000/api/v1/pomodoro/sync"

# Payload giống y hệt như Flutter App ghép lại và gửi lên
payload = {
    "user_id": "anonymous",
    "hardware_data": {
        "work_min": 20,
        "break_min": 5,
        "pauses": 0,
        "completed": False,
        "session_count": 0,
        "start_time": "2026-09-25T12:18:51",
        "end_time": "2026-09-25T12:18:53",
        "temperature": 32
    },
    "phone_data": {
        "unlock_count": 0,
        "task_type": "general",
        "recommendation_id": None,
        "timestamp": "2026-09-25T12:18:55Z"
    }
}

print("Sending test POST /api/v1/pomodoro/sync ...")
response = requests.post(url, json=payload)
print(f"Status Code: {response.status_code}")
print(f"Response: {response.text}")
